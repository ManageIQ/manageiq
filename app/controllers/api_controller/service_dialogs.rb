class ApiController
  module ServiceDialogs
    #
    # Service Dialogs
    #

    def service_dialogs_query_resource(object)
      object ? object.dialogs : []
    end

    def show_service_dialogs
      @req[:additional_attributes] = %w(content) if attribute_selection == "all"
      show_generic(:service_dialogs)
    end

    def refresh_dialog_fields_resource_service_dialogs(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Reconfiguring a #{type} resource" unless id

      api_action(type, id) do |klass|
        service_dialog = resource_search(id, type, klass)
        api_log_info("Refreshing Dialog Fields for #{service_dialog_ident(service_dialog)}")

        refresh_dialog_fields_service_dialog(service_dialog, data)
      end
    end

    #
    # Virtual attribute accessors
    #
    def fetch_service_dialogs_content(resource)
      case @req[:collection]
      when "service_templates"
        service_template = parent_resource_obj
      when "services"
        service_template = parent_resource_obj.service_template
      end
      return resource.content if service_template.nil?
      resource_action = service_template.resource_actions.where(:dialog_id => resource.id).first
      if resource_action.nil?
        raise BadRequestError,
              "#{service_dialog_ident(resource)} is not referenced by #{service_template_ident(service_template)}"
      end
      resource.content(service_template, resource_action)
    end

    private

    def service_dialog_ident(service_dialog)
      "Service Dialog id:#{service_dialog.id} label:'#{service_dialog.label}'"
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
  end
end
