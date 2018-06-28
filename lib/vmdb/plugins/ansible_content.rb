module Vmdb
  class Plugins
    class AnsibleContent
      attr_reader :path

      def initialize(path)
        raise "#{path} does not exist" unless File.directory?(path)
        roles_path = Pathname.new(path)
        @path = roles_path.split.first
      end
    end
  end
end
