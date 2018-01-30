module TaskHelpers
  class Imports
    class Roles
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |fname|
          begin
            roles = YAML.load_file(fname)
            import_roles(roles)
          rescue ActiveRecord::RecordInvalid => e
            warn("Error importing #{fname} : #{e.message}")
          end
        end
      end

      private

      def import_roles(roles)
        available_features = MiqProductFeature.all

        roles.each do |r|
          r['miq_product_feature_ids'] = available_features.collect do |f|
            f.id if r['feature_identifiers']&.include?(f.identifier)
          end.compact
          role = MiqUserRole.find_or_create_by(:name => r['name'])
          role.update_attributes!(r.reject { |k| k == 'feature_identifiers' })
        end
      end
    end
  end
end
