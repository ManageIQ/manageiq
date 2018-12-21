module TaskHelpers
  class Exports
    class CustomizationTemplates
      EXCLUDE_ATTRS = %i(created_at updated_at id pxe_image_type_id class).freeze
      def export(options = {})
        export_dir = options[:directory]

        customization_templates = options[:all] ? CustomizationTemplate.all : CustomizationTemplate.where(:system => [false, nil])

        customization_templates.order(:id).each do |customization_template|
          $log.info("Exporting Customization Template: #{customization_template.name} (ID: #{customization_template.id})")

          ct_hash = Exports.exclude_attributes(customization_template.to_model_hash, EXCLUDE_ATTRS)
          ct_hash.merge!(pxe_image_type_hash(customization_template.pxe_image_type))

          image_type_name = ct_hash.fetch_path(:pxe_image_type, :name) || "Examples"
          filename = Exports.safe_filename("#{image_type_name}-#{ct_hash[:name]}", options[:keep_spaces])
          File.write("#{export_dir}/#{filename}.yaml", ct_hash.to_yaml)
        end
      end

      private

      def pxe_image_type_hash(pxe_image_type)
        if pxe_image_type
          { :pxe_image_type => pxe_image_type.to_model_hash.reject { |key| EXCLUDE_ATTRS.include?(key) } }
        else
          { :pxe_image_type => {} }
        end
      end
    end
  end
end
