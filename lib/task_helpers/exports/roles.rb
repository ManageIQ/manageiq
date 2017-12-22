module TaskHelpers
  class Exports
    class Roles
      def export(options = {})
        export_dir = options[:directory]

        roles = if options[:all]
                  MiqUserRole.order(:id).all
                else
                  MiqUserRole.order(:id).where(:read_only => [false, nil])
                end

        roles = roles.collect do |role|
          Exports.exclude_attributes(role.attributes, %w(created_at updated_at id)).merge('feature_identifiers' => role.feature_identifiers.sort)
        end

        roles.compact

        roles.each do |r|
          fname = Exports.safe_filename(r['name'], options[:keep_spaces])
          File.write("#{export_dir}/#{fname}.yaml", [r].to_yaml)
        end
      end
    end
  end
end
