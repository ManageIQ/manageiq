module TaskHelpers
  class Imports
    class CustomizationTemplates
      class CustomizationTemplateYamlError < StandardError
        attr_accessor :details

        def initialize(message = nil, details = nil)
          super(message)
          self.details = details
        end
      end

      def import(options = {})
        return unless options[:source]

        glob = File.file?(options[:source]) ? options[:source] : "#{options[:source]}/*.yaml"
        Dir.glob(glob) do |filename|
          $log.info("Importing Customization Template from: #{filename}")

          begin
            custom_template_hash = YAML.load_file(filename)
            import_customization_template(custom_template_hash)
          rescue CustomizationTemplateYamlError => err
            $log.error("Error importing #{filename} : #{err.message}")
            warn("Error importing #{filename} : #{err.message}")
            err.details.each do |detail|
              $log.error(detail.to_s)
              warn("\t#{detail}")
            end
          end
        end
      end

      private

      def import_customization_template(custom_template_hash)
        CustomizationTemplate.transaction do
          unless valid_type?(custom_template_hash[:type])
            raise CustomizationTemplateYamlError.new("Customization Template error",
                                                     ["Invalid type: #{custom_template_hash[:type]}"])
          end

          if custom_template_hash[:system]
            raise CustomizationTemplateYamlError.new("Customization Template error",
                                                     ["Cannot import because :system is set to true"])
          end

          pxe_image_type_hash                   = custom_template_hash.delete(:pxe_image_type)
          custom_template_hash[:pxe_image_type] = get_pxe_image_type(pxe_image_type_hash)

          customization_template = CustomizationTemplate.find_by(:name           => custom_template_hash[:name],
                                                                 :pxe_image_type => custom_template_hash[:pxe_image_type])

          if customization_template
            customization_template.update(custom_template_hash)
          else
            imported_ct = CustomizationTemplate.create(custom_template_hash)

            unless imported_ct.valid?
              raise CustomizationTemplateYamlError.new("Customization Template error",
                                                       imported_ct.errors.full_messages)
            end
          end
        end
      end

      def get_pxe_image_type(pxe_image_hash)
        unless pxe_image_hash.key?(:name)
          raise CustomizationTemplateYamlError.new("Customization Template error",
                                                   ["Cannot import because there is no :name for :pxe_image_type"])
        end

        if pxe_image_hash.key?(:provision_type) && !%w(vm host).include?(pxe_image_hash[:provision_type])
          raise CustomizationTemplateYamlError.new("Customization Template error",
                                                   ["Cannot import because :provision_type for :pxe_image_type must be vm or host"])
        end

        pit = PxeImageType.find_or_create_by(pxe_image_hash)

        raise CustomizationTemplateYamlError.new("Customization Template error", pit.errors.full_messages) unless pit.valid?

        pit
      end

      def valid_type?(custom_template_type)
        CustomizationTemplate.descendants.collect(&:name).include?(custom_template_type)
      end
    end
  end
end
