# encoding: utf-8

module CarrierWave
  module Uploader
    module Versions

      depends_on CarrierWave::Uploader::Callbacks

      setup do
        after :cache, :cache_versions!
        after :store, :store_versions!
        after :remove, :remove_versions!
        after :retrieve_from_cache, :retrieve_versions_from_cache!
        after :retrieve_from_store, :retrieve_versions_from_store!
      end

      module ClassMethods

        def version_names
          @version_names ||= []
        end

        ##
        # Adds a new version to this uploader
        #
        # === Parameters
        #
        # [name (#to_sym)] name of the version
        # [options (Hash)] optional options hash
        # [&block (Proc)] a block to eval on this version of the uploader
        #
        # === Examples
        #
        #     class MyUploader < CarrierWave::Uploader::Base
        #
        #       version :thumb do
        #         process :scale => [200, 200]
        #       end
        #
        #       version :preview, :if => :image? do
        #         process :scale => [200, 200]
        #       end
        #
        #     end
        #
        def version(name, options = {}, &block)
          name = name.to_sym
          unless versions[name]
            uploader = Class.new(self)
            uploader.versions = {}

            # Define the enable_processing method for versions so they get the
            # value from the parent class unless explicitly overwritten
            uploader.class_eval <<-RUBY, __FILE__, __LINE__ + 1
              def self.enable_processing(value=nil)
                self.enable_processing = value if value
                if !@enable_processing.nil?
                  @enable_processing
                else
                  superclass.enable_processing
                end
              end
            RUBY

            # Add the current version hash to class attribute :versions
            current_version = {}
            current_version[name] = {
              :uploader => uploader,
              :options  => options
            }
            self.versions = versions.merge(current_version)

            versions[name][:uploader].version_names += [name]

            class_eval <<-RUBY
              def #{name}
                versions[:#{name}]
              end
            RUBY
            # as the processors get the output from the previous processors as their
            # input we must not stack the processors here
            versions[name][:uploader].processors = versions[name][:uploader].processors.dup
            versions[name][:uploader].processors.clear
          end
          versions[name][:uploader].class_eval(&block) if block
          versions[name]
        end

        ##
        # === Returns
        #
        # [Hash{Symbol => Class}] a list of versions available for this uploader
        #
        def versions
          @versions ||= {}
        end

      end # ClassMethods

      ##
      # Returns a hash mapping the name of each version of the uploader to an instance of it
      #
      # === Returns
      #
      # [Hash{Symbol => CarrierWave::Uploader}] a list of uploader instances
      #
      def versions
        return @versions if @versions
        @versions = {}
        self.class.versions.each do |name, klass|
          @versions[name] = klass.new(model, mounted_as)
        end
        @versions
      end

      ##
      # === Returns
      #
      # [String] the name of this version of the uploader
      #
      def version_name
        self.class.version_names.join('_').to_sym unless self.class.version_names.blank?
      end

      ##
      # When given a version name as a parameter, will return the url for that version
      # This also works with nested versions.
      #
      # === Example
      #
      #     my_uploader.url                 # => /path/to/my/uploader.gif
      #     my_uploader.url(:thumb)         # => /path/to/my/thumb_uploader.gif
      #     my_uploader.url(:thumb, :small) # => /path/to/my/thumb_small_uploader.gif
      #
      # === Parameters
      #
      # [*args (Symbol)] any number of versions
      #
      # === Returns
      #
      # [String] the location where this file is accessible via a url
      #
      def url(*args)
        if(args.first)
          raise ArgumentError, "Version #{args.first} doesn't exist!" if versions[args.first.to_sym].nil?
          # recursively proxy to version
          versions[args.first.to_sym].url(*args[1..-1])
        else
          super()
        end
      end

      ##
      # Recreate versions and reprocess them. This can be used to recreate
      # versions if their parameters somehow have changed.
      #
      def recreate_versions!
        with_callbacks(:recreate_versions, file) do
          versions.each { |name, v| v.store!(file) }
        end
      end

    private

      def full_filename(for_file)
        [version_name, super(for_file)].compact.join('_')
      end

      def full_original_filename
        [version_name, super].compact.join('_')
      end

      def cache_versions!(new_file)
        versions.each do |name, v|
          v.send(:cache_id=, cache_id)
          v.cache!(new_file)
        end
      end

      def store_versions!(new_file)
        versions.each { |name, v| v.store!(new_file) }
      end

      def remove_versions!
        versions.each { |name, v| v.remove! }
      end

      def retrieve_versions_from_cache!(cache_name)
        versions.each { |name, v| v.retrieve_from_cache!(cache_name) }
      end

      def retrieve_versions_from_store!(identifier)
        versions.each { |name, v| v.retrieve_from_store!(identifier) }
      end

    end # Versions
  end # Uploader
end # CarrierWave