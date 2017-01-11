module Api
  module Subcollections
    module ServiceTemplates
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

      def service_templates_order_resource(_object, type, id = nil, data = nil)
        klass = collection_class(:service_templates)
        service_template = resource_search(id, type, klass)
        workflow = ServiceTemplateWorkflow.create(service_template, data || {})
        request_result = workflow.submit_request
        errors = request_result[:errors]
        if errors.present?
          raise BadRequestError, "Failed to order #{service_template_ident(service_template)} - #{errors.join(", ")}"
        end
        request_result[:request]
      end

      def service_templates_refresh_dialog_fields_resource(object, type, id = nil, data = nil)
        raise BadRequestError, "Must specify an id for Refreshing dialog fields of a #{type} resource" unless id

        service_template_subcollection_action(type, id) do |st|
          api_log_info("Refreshing dialog fields for #{service_template_ident(st)}")

          refresh_dialog_fields_service_template(object, st, data)
        end
      end

      def delete_resource_service_templates(_parent, type, id, data)
        delete_resource(type, id, data)
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
        action_result(false, err.to_s)
      end

      def refresh_dialog_fields_service_template(_object, st, data)
        data ||= {}
        dialog_fields = Hash(data["dialog_fields"])
        refresh_fields = data["fields"]
        return action_result(false, "Must specify fields to refresh") if refresh_fields.blank?

        dialog = define_service_template_dialog(st, dialog_fields)
        return action_result(false, "Service Template has no provision dialog defined") unless dialog

        refresh_dialog_fields_action(dialog, refresh_fields, service_template_ident(st))
      rescue => err
        action_result(false, err.to_s)
      end

      def define_service_template_dialog(st, dialog_fields)
        resource_action = st.resource_actions.find_by_action("Provision")
        workflow = ResourceActionWorkflow.new({}, User.current_user, resource_action, :target => st)
        dialog_fields.each { |key, value| workflow.set_value(key, value) }
        workflow.dialog
      end
    end
  end
end
