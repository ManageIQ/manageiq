module TaskHelpers
  class Exports
    class PolicySets
      def export(options = {})
        export_dir = options[:directory]

        policy_sets = if options[:all]
                        MiqPolicySet.order(:id).all
                      else
                        MiqPolicySet.order(:id).where(:read_only => [false, nil])
                      end

        policy_sets.each do |p|
          fname = Exports.safe_filename(p.description, options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", p.export_to_yaml)
        end
      end
    end
  end
end
