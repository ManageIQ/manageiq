class ApiController
  module ServiceTemplates
    #
    # ServiceTemplates Subcollection Supporting Methods
    #

    def service_templates_query_resource(object)
      klass = collection_class(:service_templates)
      object ? klass.where(:service_template_catalog_id => object.id) : {}
    end

    def service_templates_assign_resource(object, type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for Assigning a #{type} resource" unless id

      service_template_subcollection_action(type, id) do |st|
        api_log_info("Assigning #{service_template_ident(st)}")

        assign_service_template(object, st)
      end
    end

    def service_templates_unassign_resource(object, type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for Unassigning a #{type} resource" unless id

      service_template_subcollection_action(type, id) do |st|
        api_log_info("Unassigning #{service_template_ident(st)}")

        unassign_service_template(object, st)
      end
    end

    def service_templates_order_resource(_object, _type, id = nil, data = nil)
      klass = collection_class(:service_templates)
      options = {:dialog => {}, :src_id => id}
      unless data.nil?
        data.each do |key, value|
          dkey = "dialog_#{key}"
          options[:dialog][dkey] = value unless value.empty?
        end
      end

      klass.new.request_class.make_request(nil, options, @auth_user_obj)
    end

    def service_templates_refresh_dialog_fields_resource(object, type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Refreshing dialog fields of a #{type} resource" unless id

      service_template_subcollection_action(type, id) do |st|
        api_log_info("Refreshing dialog fields for #{service_template_ident(st)}")

        refresh_dialog_fields_service_template(object, st, data)
      end
    end

    private

    def service_template_ident(st)
      "Service Template id:#{st.id} name:'#{st.name}'"
    end

    def service_template_subcollection_action(type, id)
      klass = collection_class(:service_templates)
      result =
        begin
          st = resource_search(id, type, klass)
          yield(st) if block_given?
        rescue => err
          action_result(false, err.to_s)
        end
      add_subcollection_resource_to_result(result, type, st) if st
      add_parent_href_to_result(result)
      log_result(result)
      result
    end

    def assign_service_template(object, st)
      stcid = st.service_template_catalog_id
      if stcid
        action_result(stcid == object.id, "Service Template #{st.id} is currently assigned to Service Catalog #{stcid}")
      else
        object.service_templates << st
        action_result(true, "Assigning #{service_template_ident(st)}")
      end
    rescue => err
      action_result(false, err.to_s)
    end

    def unassign_service_template(object, st)
      stcid = st.service_template_catalog_id
      if stcid
        if stcid != object.id
          action_result(false, "Service Template #{st.id} is not currently assigned to Service Catalog #{stcid}")
        else
          object.service_templates -= Array.wrap(st)
          action_result(true, "Unassigning #{service_template_ident(st)}")
        end
      else
        action_result(true, "Service Template #{st.id} is not currently assigned to a Service Catalog")
      end
    rescue => err
      action_result(false, err)
    end

    def refresh_dialog_fields_service_template(_object, st, data = {})
      dialog_fields = Hash(data["dialog_fields"])
      refresh_fields = data["fields"]
      return action_result(false, "Must specify fields to refresh") if refresh_fields.blank?

      dialog = define_service_template_dialog(st, dialog_fields)
      return action_result(false, "Service Template has no provision dialog defined") unless dialog

      refresh_dialog_fields_action(st, dialog, refresh_fields)
    rescue => err
      action_result(false, err)
    end

    def define_service_template_dialog(st, dialog_fields)
      resource_action = st.resource_actions.find_by_action("Provision")
      workflow = ResourceActionWorkflow.new({}, @auth_user_obj, resource_action, :target => st)
      dialog_fields.each { |key, value| workflow.set_value(key, value) }
      workflow.dialog
    end

    def refresh_dialog_fields_action(st, dialog, refresh_fields)
      result = {}
      refresh_fields.each do |field|
        dynamic_field = dialog.field(field)
        return action_result(false, "Unknown dialog field #{field} specified") unless dynamic_field
        unless dynamic_field.respond_to?(:update_and_serialize_values)
          return action_result(false, "Dialog field #{field} specified cannot be refreshed")
        end
        result[field] = dynamic_field.update_and_serialize_values
      end
      action_result(true, "Refreshing dialog fields for #{service_template_ident(st)}", :result => result)
    end
  end
end
