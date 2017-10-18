class PhysicalServerProvisionRequest < MiqProvisionConfiguredSystemRequest
  TASK_DESCRIPTION  = 'Physical Server Provisioning'.freeze
  SOURCE_CLASS_NAME = 'PhysicalServer'.freeze

  def src_configured_systems
    PhysicalServer.where(:id => options[:src_configured_system_ids])
  end

  def self.request_task_class_from(_attribs)
    ManageIQ::Providers::Lenovo::PhysicalInfraManager
  end

  def event_name(mode)
    "physical_server_provision_request_#{mode}"
  end

  def originating_controller
    "physical_server"
  end
end
