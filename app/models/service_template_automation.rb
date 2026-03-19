class ServiceTemplateAutomation < ServiceTemplate
  def self.available_managers
    automation_manager_klass.all
  end

  def self.automation_manager_klass
    @automation_manager_klass ||= "ManageIQ::Providers::#{name.sub("ServiceTemplate", "")}::AutomationManager".constantize
  end

  delegate :available_managers, :to => :class
end
