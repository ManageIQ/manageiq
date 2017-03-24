module Api
  class ServicesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::Vms
    include Subcollections::OrchestrationStacks

    def create_resource(_type, _id, data)
      validate_service_data(data)
      attributes = build_service_attributes(data)
      service    = collection_class(:services).create(attributes)
      validate_service(service)
      service
    end

    def edit_resource(type, id, data)
      attributes = build_service_attributes(data)
      super(type, id, attributes)
    end

    def add_resource_resource(type, id, data)
      raise "Must specify a service href or id to add_resource to" unless id
      svc = resource_search(id, type, collection_class(type))

      resource_href = data.fetch_path("resource", "href")
      raise "Must specify a resource reference" unless resource_href

      resource_type, resource_id = parse_href(resource_href)
      raise "Invalid resource href specified #{resource_href}" unless resource_type && resource_id

      resource = resource_search(resource_id, resource_type, collection_class(resource_type))
      raise "Cannot assign #{resource_type} to #{service_ident(svc)}" unless resource.respond_to? :add_to_service

      resource.add_to_service(svc)
      action_result(true, "Assigned resource #{resource_type} id:#{resource_id} to #{service_ident(svc)}")
    rescue => err
      action_result(false, err.to_s)
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

    def start_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        service = resource_search(id, type, klass)
        api_log_info("Starting #{service_ident(service)}")

        begin
          description = "#{service_ident(service)} starting"
          task_id = queue_object_action(service, description, :method_name => "start", :role => "ems_operations")
          action_result(true, description, :task_id => task_id)
        rescue => e
          action_result(false, e.to_s)
        end
      end
    end

    def stop_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        service = resource_search(id, type, klass)
        api_log_info("Stopping #{service_ident(service)}")

        begin
          description = "#{service_ident(service)} stopping"
          task_id = queue_object_action(service, description, :method_name => "stop", :role => "ems_operations")
          action_result(true, description, :task_id => task_id)
        rescue => e
          action_result(false, e.to_s)
        end
      end
    end

    def suspend_resource(type, id = nil, _data = nil)
      raise BadRequestError, "Must specify an id for starting a #{type} resource" unless id

      api_action(type, id) do |klass|
        service = resource_search(id, type, klass)
        api_log_info("Suspending #{service_ident(service)}")

        begin
          description = "#{service_ident(service)} suspending"
          task_id = queue_object_action(service, description, :method_name => "suspend", :role => "ems_operations")
          action_result(true, description, :task_id => task_id)
        rescue => e
          action_result(false, e.to_s)
        end
      end
    end

    private

    def build_service_attributes(data)
      attributes                 = data.dup
      attributes['job_template'] = fetch_configuration_script(data['job_template']) if data['job_template']
      attributes['parent']       = fetch_service(data['parent_service']) if data['parent_service']
      if data['orchestration_manager']
        attributes['orchestration_manager'] = fetch_ext_management_system(data['orchestration_manager'])
      end
      if data['orchestration_template']
        attributes['orchestration_template'] = fetch_orchestration_template(data['orchestration_template'])
      end
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
    end

    def validate_service(service)
      if service.invalid?
        raise BadRequestError, "Failed to add new service -
            #{service.errors.full_messages.join(', ')}"
      end
    end

    def fetch_ext_management_system(data)
      orchestration_manager_id = parse_id(data, :providers)
      raise BadRequestError, 'Missing ExtManagementSystem identifier id' if orchestration_manager_id.nil?
      resource_search(orchestration_manager_id, :ext_management_systems, ExtManagementSystem)
    end

    def fetch_service(data)
      service_id = parse_id(data, :services)
      raise BadRequestError, 'Missing Service identifier id' if service_id.nil?
      resource_search(service_id, :services, Service)
    end

    def fetch_orchestration_template(data)
      orchestration_template_id = parse_id(data, :orchestration_templates)
      raise BadRequestError, 'Missing OrchestrationTemplate identifier id' if orchestration_template_id.nil?
      resource_search(orchestration_template_id, :orchestration_templates, OrchestrationTemplate)
    end

    def fetch_configuration_script(data)
      configuration_script_id = parse_id(data, :configuration_script)
      raise BadRequestError, 'Missing ConfigurationScript identifier id' if configuration_script_id.nil?
      resource_search(configuration_script_id, :configuration_scripts, ConfigurationScript)
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
      wf = ResourceActionWorkflow.new({}, User.current_user, ra, :target => svc)
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
