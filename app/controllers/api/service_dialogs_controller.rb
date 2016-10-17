module Api
  class ServiceDialogsController < BaseController
    before_action :set_additional_attributes, :only => [:show]

    def refresh_dialog_fields_resource(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Reconfiguring a #{type} resource" unless id

      api_action(type, id) do |klass|
        service_dialog = resource_search(id, type, klass)
        api_log_info("Refreshing Dialog Fields for #{service_dialog_ident(service_dialog)}")

        refresh_dialog_fields_service_dialog(service_dialog, data)
      end
    end

    def create_resource(_type, _id, data)
      DialogImportService.new.import(data)
    rescue => e
      raise BadRequestError, "Failed to create a new dialog - #{e}"
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(content) if attribute_selection == "all"
    end

    def refresh_dialog_fields_service_dialog(service_dialog, data)
      data ||= {}
      dialog_fields = Hash(data["dialog_fields"])
      refresh_fields = data["fields"]
      return action_result(false, "Must specify fields to refresh") if refresh_fields.blank?

      define_service_dialog_fields(service_dialog, dialog_fields)

      refresh_dialog_fields_action(service_dialog, refresh_fields, service_dialog_ident(service_dialog))
    rescue => err
      action_result(false, err.to_s)
    end

    def define_service_dialog_fields(service_dialog, dialog_fields)
      ident = service_dialog_ident(service_dialog)
      dialog_fields.each do |key, value|
        dialog_field = service_dialog.field(key)
        raise BadRequestError, "Dialog field #{key} specified does not exist in #{ident}" if dialog_field.nil?
        dialog_field.value = value
      end
    end

    def service_dialog_ident(service_dialog)
      "Service Dialog id:#{service_dialog.id} label:'#{service_dialog.label}'"
    end
  end
end
