module Api
  class ServiceTemplateWorkflow
    def self.create(service_template, service_request)
      resource_action = service_template.resource_actions.find_by_action("Provision")
      workflow = ResourceActionWorkflow.new({}, User.current_user, resource_action, :target => service_template)
      service_request.each { |key, value| workflow.set_value(key, value) } if service_request.present?
      workflow
    end
  end
end
