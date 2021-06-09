module TaskHelpers
  class Exports
    class CustomButtons
      EXCLUDE_ATTRS = %w[id miq_set_id created_on updated_on created_at updated_at dialog_id resource_id].freeze

      def initialize
        @export_hash = {}
      end

      def export(options = {})
        export_custom_buttons_sets
        export_direct_custom_buttons

        File.write("#{options[:directory]}/CustomButtons.yaml", YAML.dump(@export_hash))
      end

      def export_custom_buttons_sets
        @export_hash["custom_button_set"] = []

        CustomButtonSet.all.order(:id).each do |button_set|
          log_export(button_set)

          children = {}
          export_direct_custom_buttons(button_set.custom_buttons, children)

          @export_hash["custom_button_set"] << attrs_for(button_set, children)
        end
      end

      def export_direct_custom_buttons(buttons = direct_custom_buttons, result = @export_hash)
        result["custom_button"] = []

        buttons.each do |custom_button|
          log_export(custom_button)

          result["custom_button"] << attrs_for(custom_button)
        end
      end

      private

      def direct_custom_buttons
        CustomButton.select("custom_buttons.*, miq_set_memberships.miq_set_id")
                    .left_outer_joins(:miq_set_memberships)
                    .where(:miq_set_memberships => {:miq_set_id => nil})
      end

      def attrs_for(object, children = nil)
        attrs               = {}
        attrs["attributes"] = object.attributes.except(*EXCLUDE_ATTRS)
        attrs["children"]   = children if children

        if (resource_action = object.try(:resource_action))
          attrs["associations"] = {"resource_action" => [attrs_for(resource_action)]}
        end

        if (label = object.try(:dialog).try(:label))
          attrs["attributes"]["dialog_label"] = label
        end

        attrs
      end

      def log_export(object)
        $log.info("Exporting #{object.class.name}: #{object.try('name')} (ID: #{object&.id})")
      end
    end
  end
end
