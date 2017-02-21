module Api
  module Shared
    module CustomActions
      def custom_action_resource(type, id, data = nil)
        action = @req.action.downcase
        id ||= @req.c_id
        if id.blank?
          raise BadRequestError, "Must specify an id for invoking the custom action #{action} on a #{type} resource"
        end

        api_log_info("Invoking #{action} on #{type} id #{id}")
        resource = resource_search(id, type, collection_class(type))
        unless resource_custom_action_names(resource).include?(action)
          raise BadRequestError, "Unsupported Custom Action #{action} for the #{type} resource specified"
        end
        invoke_custom_action(type, resource, action, data)
      end

      def invoke_custom_action(type, resource, action, data)
        custom_button = resource_custom_action_button(resource, action)
        if custom_button.resource_action.dialog_id
          return invoke_custom_action_with_dialog(type, resource, action, data, custom_button)
        end

        result = begin
                   custom_button.invoke(resource)
                   action_result(true, "Invoked custom action #{action} for #{type} id: #{resource.id}")
                 rescue => err
                   action_result(false, err.to_s)
                 end
        add_href_to_result(result, type, resource.id)
        log_result(result)
        result
      end

      def invoke_custom_action_with_dialog(type, resource, action, data, custom_button)
        result = begin
                   wf_result = submit_custom_action_dialog(resource, custom_button, data)
                   action_result(true,
                                 "Invoked custom dialog action #{action} for #{type} id: #{resource.id}",
                                 :result => wf_result[:request])
                 rescue => err
                   action_result(false, err.to_s)
                 end
        add_href_to_result(result, type, resource.id)
        log_result(result)
        result
      end

      def submit_custom_action_dialog(resource, custom_button, data)
        wf = ResourceActionWorkflow.new({}, User.current_user, custom_button.resource_action, :target => resource)
        data.each { |key, value| wf.set_value(key, value) } if data.present?
        wf_result = wf.submit_request
        raise StandardError, Array(wf_result[:errors]).join(", ") if wf_result[:errors].present?
        wf_result
      end

      def resource_custom_action_button(resource, action)
        resource.custom_action_buttons.find { |b| b.name.downcase == action.downcase }
      end
    end
  end
end
