require 'yaml'

module PgInspector
  class Util
    def self.dump_to_yml_file(obj, name, output)
      puts "Exporting #{name} to #{output} ..."
      File.open(output, 'w') do |output_file|
        YAML.dump(obj, output_file)
      end
      puts "Exporting #{name} to #{output} ... Complete"
    end

    def self.error_exit(e, exit_code = 1)
      $stderr.puts e.message
      exit(exit_code)
    end

    def self.error_msg_exit(e_msg, exit_code = 1)
      $stderr.puts e_msg
      exit(exit_code)
    end
  end
end
