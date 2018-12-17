module Vmdb
  class Plugins
    class AutomateDomain
      attr_reader :datastores_path
      attr_reader :name
      attr_reader :path

      def initialize(path)
        raise "#{path} is not a directory" unless File.directory?(path)
        @path            = Pathname.new(path)
        @datastores_path = @path.split.first
        @name            = config.fetch_path("object", "attributes", "name")
      end

      def system?
        @system ||= config.fetch_path("object", "attributes", "source") == "system"
      end

      private

      def config
        YAML.load_file(config_file_path)
      end

      def config_file_path
        @config_file_path ||= path.join("__domain__.yaml").tap do |config_file|
          raise "Missing config file #{config_file}" unless File.file?(config_file)
        end
      end
    end
  end
end
