# Patches the database_configuration method to not evaluate ERB in production
# mode for security purposes.  Also, adds support to handle encrypted
# password fields as strings without ERB.
#
# The original implementation is as follows:
#
#    def database_configuration
#      require 'erb'
#      YAML::load(ERB.new(IO.read(paths["config/database"].first)).result)
#    end
module Rails
  class Application
    class Configuration
      def database_configuration
        data = IO.read(paths["config/database"].first)
        Vmdb::ConfigurationEncoder.load(data, false)
      end
    end
  end
end
