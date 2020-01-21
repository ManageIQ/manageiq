module TaskHelpers
  class Imports
    class PolicySets
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Policy Profiles from: #{filename}")

          begin
            policysets = YAML.load_file(filename)
            import_policysets(policysets)
          rescue StandardError => err
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end

      private

      def import_policysets(policysets)
        MiqPolicySet.transaction do
          policysets.each do |policyset|
            MiqPolicySet.import_from_hash(policyset['MiqPolicySet'], :save => true)
          end
        end
      end
    end
  end
end
