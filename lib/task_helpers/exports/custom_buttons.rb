module TaskHelpers
  class Exports
    class CustomButtons
      class ExportArInstances
        EXCLUDE_ATTRS = %w(id created_on updated_on created_at updated_at dialog_id resource_id).freeze
        def self.export_object(obj, hash)
          class_name = obj.class.name.underscore

          $log.info("Exporting #{obj.class.name}: #{obj.try('name')} (ID: #{obj&.id})")
          (hash[class_name] ||= []) << item = { 'attributes' => build_attr_list(obj.try(:attributes)) }
          create_association_list(obj, item)
          descendant_list(obj, item)
        end

        def self.build_attr_list(attrs)
          attrs&.except(*EXCLUDE_ATTRS)
        end

        def self.create_association_list(obj, item)
          associations = obj.class.try(:reflections)
          if associations
            associations = associations.collect { |model, assoc| { model => assoc.class.to_s.demodulize } }.select { |as| as.values.first != "BelongsToReflection" && as.keys.first != "all_relationships" }
            associations.each do |assoc|
              assoc.each do |a|
                next if obj.try(a.first.to_sym).blank?
                export_object(obj.try(a.first.to_sym), (item['associations'] ||= {}))
              end
            end
          end
        end

        def self.descendant_list(obj, item)
          obj.try(:children)&.each { |c| export_object(c, (item['children'] ||= {})) }
        end
      end

      def export(options = {})
        parent_id_list = []
        objects = CustomButton.where.not(:applies_to_class => %w(ServiceTemplate GenericObject))

        export = objects.each_with_object({}) do |obj, export_hash|
          if obj.try(:parent).present?
            next if parent_id_list.include?(obj.parent.id)
            ExportArInstances.export_object(obj.parent, export_hash)
            parent_id_list << obj.parent.id
          else
            ExportArInstances.export_object(obj, export_hash)
          end
        end

        export_dir = options[:directory]
        File.write("#{export_dir}/CustomButtons.yaml", YAML.dump(export))
      end
    end
  end
end
