module Api
  class ServiceTemplatesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::ResourceActions
    include Subcollections::ServiceRequests

    before_action :set_additional_attributes, :only => [:show]

    def create_resource(_type, _id, data)
      # Temporarily only supporting atomic.
      raise 'Service Type composite not supported' if data['service_type'] == 'composite'
      create_atomic(data).tap(&:save!)
    rescue => err
      raise BadRequestError, "Could not create Service Template - #{err}"
    end

    private

    def set_additional_attributes
      @additional_attributes = %w(config_info)
    end

    def create_atomic(data)
      service_template = ServiceTemplate.new(data.except('config_info'))
      config_info = data['config_info'].nil? ? {} : data['config_info']
      case service_template.type
      when 'ServiceTemplateOrchestration'
        add_orchestration_template_vars(service_template, config_info)
      when 'ServiceTemplateAnsibleTower'
        add_ansible_tower_job_template_vars(service_template, config_info)
      else
        service_template.add_resource(create_service_template_request(config_info)) unless config_info == {}
      end
      dialog = Dialog.find(config_info['dialog_id']) if config_info['dialog_id']
      service_template.set_resource_actions(config_info, dialog)
      service_template
    end

    # Need to set the request for non-generic Service Template
    def create_service_template_request(request_data)
      # data must be symbolized
      request_params = request_data.symbolize_keys
      wf = MiqProvisionWorkflow.class_for_source(request_params[:src_vm_id]).new(request_params, @auth_user_obj)
      raise 'Could not find Provision Workflow class for source VM' unless wf
      request = wf.make_request(nil, request_params)
      raise 'Could not create valid request' if request == false || !request.valid?
      request
    end

    def add_orchestration_template_vars(service_template, config_info)
      service_template.orchestration_template = unless config_info['template_id'].nil?
                                                  OrchestrationTemplate.find(config_info['template_id'])
                                                end
      service_template.orchestration_manager = unless config_info['manager_id'].nil?
                                                 ExtManagementSystem.find(config_info['manager_id'])
                                               end
    end

    def add_ansible_tower_job_template_vars(service_template, config_info)
      service_template.job_template = unless config_info['template_id'].nil?
                                        ConfigurationScript.find(config_info['template_id'])
                                      end
    end
  end
end
