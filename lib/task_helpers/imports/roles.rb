module TaskHelpers
  class Imports
    class Roles
      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Roles from: #{filename}")

          begin
            roles = YAML.load_file(filename)
            import_roles(roles)
          rescue ActiveRecord::RecordInvalid => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
          end
        end
      end

      private

      def import_roles(roles)
        available_features = MiqProductFeature.all

        roles.each do |role|
          role['miq_product_feature_ids'] = available_features.collect do |feature|
            feature.id if role['feature_identifiers']&.include?(feature.identifier)
          end.compact
          found_role = MiqUserRole.find_or_create_by(:name => role['name'])
          found_role.update!(role.reject { |key| key == 'feature_identifiers' })
        end
      end
    end
  end
end
