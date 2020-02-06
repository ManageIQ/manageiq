class PhysicalServerProvisionRequest < MiqRequest
  TASK_DESCRIPTION  = 'Physical Server Provisioning'.freeze
  SOURCE_CLASS_NAME = 'PhysicalServer'.freeze

  def description
    'Physical Server Provisioning'
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    source.nil? ? super : source.queue_name_for_ems_operations
  end

  def source
    @source ||= PhysicalServer.find_by(:id => source_id)
  end

  def self.request_task_class
    PhysicalServerProvisionTask
  end

  def self.new_request_task(attribs)
    source = source_physical_server(attribs[:source_id])
    source.ext_management_system.class.provision_class(nil).new(attribs)
  end

  def self.source_physical_server(source_id)
    PhysicalServer.find_by(:id => source_id).tap do |source|
      raise MiqException::MiqProvisionError, "Unable to find source PhysicalServer with id [#{source_id}]" if source.nil?
      raise MiqException::MiqProvisionError, "Source PhysicalServer with id [#{source_id}] has no EMS, unable to provision" if source.ext_management_system.nil?
    end
  end
end
