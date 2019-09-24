module TaskHelpers
  class Exports
    class PolicySets
      def export(options = {})
        export_dir = options[:directory]

        policy_sets = options[:all] ? MiqPolicySet.all : MiqPolicySet.where(:read_only => [false, nil])

        policy_sets.order(:id).each do |policy_set|
          $log.info("Exporting Policy Profile: #{policy_set.description} (ID: #{policy_set.id})")

          filename = Exports.safe_filename(policy_set.description, options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", policy_set.export_to_yaml)
        end
      end
    end
  end
end
