class ApiController
  module Services
    def reconfigure_resource_services(type, id = nil, data = nil)
      raise BadRequestError, "Must specify an id for Reconfiguring a #{type} resource" unless id

      api_action(type, id) do |klass|
        svc = resource_search(id, type, klass)
        api_log_info("Reconfiguring #{service_ident(svc)}")

        result = validate_service_for_action(svc, "reconfigure")
        result = invoke_reconfigure_dialog(type, svc, data) if result[:success]
        result
      end
    end

    private

    def service_ident(svc)
      "Service id:#{svc.id} name:'#{svc.name}'"
    end

    def invoke_reconfigure_dialog(type, svc, data = {})
      result = begin
        wf_result = submit_reconfigure_dialog(svc, data)
        action_result(true, "#{service_ident(svc)} reconfiguring", :result => wf_result[:request])
      rescue => err
        action_result(false, err.to_s)
      end
      add_href_to_result(result, type, svc.id)
      log_result(result)
      result
    end

    def submit_reconfigure_dialog(svc, data)
      ra = svc.reconfigure_resource_action
      wf = ResourceActionWorkflow.new({}, @auth_user_obj, ra, :target => svc)
      data.each { |key, value| wf.set_value(key, value) } if data.present?
      wf_result = wf.submit_request
      raise StandardError, Array(wf_result[:errors]).join(", ") if wf_result[:errors].present?
      wf_result
    end

    def validate_service_for_action(svc, action)
      valid = svc.send("validate_#{action}")
      msg = valid ? "" : "Action #{action} is not available for #{service_ident(svc)}"
      action_result(valid, msg)
    end
  end
end
