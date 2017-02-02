module Api
  module Shared
    module DialogFields
      def refresh_dialog_fields_action(dialog, refresh_fields, resource_ident)
        result = {}
        refresh_fields.each do |field|
          dynamic_field = dialog.field(field)
          return action_result(false, "Unknown dialog field #{field} specified") unless dynamic_field
          result[field] = dynamic_field.update_and_serialize_values
        end
        action_result(true, "Refreshing dialog fields for #{resource_ident}", :result => result)
      end
    end
  end
end
