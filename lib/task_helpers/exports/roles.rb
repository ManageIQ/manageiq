module TaskHelpers
  class Exports
    class Roles
      EXCLUDE_ATTRS = %w(created_at updated_at id).freeze
      def export(options = {})
        export_dir = options[:directory]

        roles = options[:all] ? MiqUserRole.all : MiqUserRole.where(:read_only => [false, nil])

        roles.order(:id).each do |role|
          $log.info("Exporting Role: #{role.name} (ID: #{role.id})")

          role_hash = Exports.exclude_attributes(role.attributes, EXCLUDE_ATTRS).merge('feature_identifiers' => role.feature_identifiers.sort)

          filename = Exports.safe_filename(role_hash['name'], options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", [role_hash].to_yaml)
        end
      end
    end
  end
end
