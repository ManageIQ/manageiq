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
      service_template = ServiceTemplate.new(data.except('request_info'))
      dialog = nil
      if data.key?('request_info')
        service_template.add_resource(create_service_template_request(data['request_info']))
        dialog = Dialog.find(data['request_info']['dialog_id']) if data['request_info']['dialog_id']
      end
      set_provision_action(service_template, dialog, data['request_info'])
      set_retirement_reconfigure_action(service_template, dialog, data['request_info'])
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

    def set_provision_action(service_template, dialog, request_info)
      fqname = if request_info && request_info['fqname']
                 request_info['fqname']
               else
                 service_template.class.default_provisioning_entry_point(service_template.service_type)
               end
      ra = service_template.resource_actions.build(:action => 'Provision')
      ra.update_attributes(:dialog => dialog, :fqname => fqname)
    end

    def set_retirement_reconfigure_action(service_template, dialog, request_info)
      [
        {:name => 'Reconfigure', :param_key => 'reconfigure_fqname', :method => 'default_reconfiguration_entry_point'},
        {:name => 'Retirement', :param_key => 'retire_fqname', :method => 'default_retirement_entry_point'}
      ].each do |action|
        ra = service_template.resource_actions.build(:action => action[:name], :dialog => dialog)
        fqname = if request_info && request_info[action[:param_key]]
                   request_info[action[:param_key]]
                 else
                   service_template.class.send(action[:method])
                 end
        ra.update_attributes(:fqname => fqname) if fqname
      end
    end
  end
end
