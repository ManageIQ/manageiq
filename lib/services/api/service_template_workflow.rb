module Api
  class ServiceTemplateWorkflow
    def self.create(service_template, service_request)
      service_template.provision_workflow(User.current_user, service_request)
    end
  end
end
