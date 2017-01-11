module Api
  class ServiceTemplateWorkflow
    def self.create(service_template, service_request)
      resource_action = service_template.provision_action
      workflow = ResourceActionWorkflow.new({}, User.current_user, resource_action, :target => service_template)
      service_request.each { |key, value| workflow.set_value(key, value) } if service_request.present?
      workflow
    end
  end
end
