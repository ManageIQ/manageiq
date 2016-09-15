module Api
  class ServicesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::Vms

    def create_resource(_type, _id, data)
      validate_service_data(data)
      attributes = build_service_attributes(data)
      service    = collection_class(:services).create(attributes)
      validate_service(service)
      service
    end

    def reconfigure_resource(type, id = nil, data = nil)
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

    def build_service_attributes(data)
      attributes                           = data.dup
      attributes['orchestration_manager']  = fetch_ext_management_system(data['orchestration_manager']) if data['orchestration_manager']
      attributes['orchestration_template'] = fetch_orchestration_template(data['orchestration_template']) if data['orchestration_template']
      attributes['job_template']           = fetch_configuration_script(data['job_template']) if data['job_template']
      attributes['parent']                 = fetch_service(data['parent_service']) if data['parent_service']
      if data['job_options']
        # AnsibleTowerClient needs the keys to be symbols
        attributes['job_options'][:limit]      ||= data['job_options'].delete('limit')
        attributes['job_options'][:extra_vars] ||= data['job_options'].delete('extra_vars')
      end
      attributes.delete('parent_service')
      attributes
    end

    def validate_service_data(data)
      assert_id_not_specified(data, 'service')

      @collection_klasses = {:ext_management_systems  => ExtManagementSystem,
                             :services                => Service,
                             :configuration_scripts   => ConfigurationScript,
                             :orchestration_templates => OrchestrationTemplate}
    end

    def validate_service(service)
      if service.invalid?
        raise BadRequestError, "Failed to add new service -
            #{service.errors.full_messages.join(', ')}"
      end
    end

    def fetch_ext_management_system(data)
      orchestration_manager_id = parse_id(data, :orchestration_manager)
      raise BadRequestError, 'Missing ExtManagementSystem identifier id' if orchestration_manager_id.nil?
      resource_search(orchestration_manager_id, :ext_management_systems, collection_class(:ext_management_systems))
    end

    def fetch_service(data)
      service_id = parse_id(data, :service)
      raise BadRequestError, 'Missing Service identifier id' if service_id.nil?
      resource_search(service_id, :services, collection_class(:services))
    end

    def fetch_orchestration_template(data)
      orchestration_template_id = parse_id(data, :orchestration_template)
      raise BadRequestError, 'Missing OrchestrationTemplate identifier id' if orchestration_template_id.nil?
      resource_search(orchestration_template_id, :orchestration_templates, collection_class(:orchestration_templates))
    end

    def fetch_configuration_script(data)
      configuration_script_id = parse_id(data, :configuration_script)
      raise BadRequestError, 'Missing ConfigurationScript identifier id' if configuration_script_id.nil?
      resource_search(configuration_script_id, :configuration_scripts, collection_class(:configuration_scripts))
    end

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
