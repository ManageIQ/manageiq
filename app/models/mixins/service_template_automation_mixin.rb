module ServiceTemplateAutomationMixin
  extend ActiveSupport::Concern

  class_methods do
    def available_managers
      automation_manager_klass.all
    end

    def automation_manager_klass
      @automation_manager_klass ||= "ManageIQ::Providers::#{name.sub("ServiceTemplate", "")}::AutomationManager".constantize
    end
  end

  delegate :available_managers, :to => :class
end
