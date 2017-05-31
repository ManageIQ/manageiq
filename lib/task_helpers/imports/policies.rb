module TaskHelpers
  class Imports
    class Policies
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |fname|
          begin
            policies = YAML.load_file(fname)
            import_policies(policies)
          rescue => e
            $stderr.puts "Error importing #{fname} : #{e.message}"
          end
        end
      end

      private

      def import_policies(policies)
        MiqPolicy.transaction do
          policies.each do |policy|
            MiqPolicy.import_from_hash(policy['MiqPolicy'], :save => true)
          end
        end
      end
    end
  end
end
