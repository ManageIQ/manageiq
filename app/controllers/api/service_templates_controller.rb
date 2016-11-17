module Api
  class ServiceTemplatesController < BaseController
    include Subcollections::ServiceDialogs
    include Subcollections::Tags
    include Subcollections::ResourceActions
    include Subcollections::ServiceRequests

    before_action :set_additional_attributes, :only => [:show]

    def create_resource(_type, _id, data)
      # Temporarily only supporting atomic.
      # Will update API to support composite separately.
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
      validate_atomic_data(data)
      service_template = ServiceTemplate.new(data.except('request_info'))
      service_template.add_resource(create_service_template_request(data))
      set_new_resource_actions(data['request_info'], service_template)
    end

    def validate_atomic_data(data)
      raise 'Must provide request info' unless data.key?('request_info')
      raise 'Provisioning Entry Point is required' unless data['request_info']['fqname']
      raise 'Source VM is required' unless data['request_info']['src_vm_id']
    end

    # Need to set the request for non-generic Service Template
    def create_service_template_request(data)
      # hash must be passed as symbols
      request_params = data['request_info'].symbolize_keys
      wf = MiqProvisionWorkflow.class_for_source(data['request_info']['src_vm_id']).new(request_params, @auth_user_obj)
      raise 'Could not find Provision Workflow class for source VM' unless wf
      request = wf.make_request(nil, request_params)
      raise 'Could not create valid request' if request == false || !request.valid?
      request
    end

    # Set Resource Actions
    def set_new_resource_actions(data, service_template)
      dialog = data['dialog_id'].nil? ? nil : Dialog.find(data['dialog_id'])
      [
        {:name => 'Provision', :params_key => 'fqname'},
        {:name => 'Reconfigure', :params_key => 'reconfigure_fqname'},
        {:name => 'Retirement', :params_key => 'retire_fqname'}
      ].each do |action|
        unless data[action[:params_key]].nil?
          ra = service_template.resource_actions.build(:action => action[:name])
          ra.update_attributes(:dialog => dialog, :fqname => data[action[:params_key]])
        end
      end
      service_template
    end
  end
end
