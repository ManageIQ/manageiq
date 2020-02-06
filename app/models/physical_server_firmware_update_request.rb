class PhysicalServerFirmwareUpdateRequest < MiqRequest
  TASK_DESCRIPTION  = 'Physical Server Firmware Update'.freeze
  SOURCE_CLASS_NAME = 'PhysicalServer'.freeze

  def description
    'Physical Server Firmware Update'
  end

  def my_role(_action = nil)
    'ems_operations'
  end

  def my_queue_name
    affected_ems.queue_name_for_ems_operations
  end

  def self.request_task_class
    PhysicalServerFirmwareUpdateTask
  end

  def self.new_request_task(attribs)
    affected_ems(attribs).class.firmware_update_class.new(attribs)
  end

  def requested_task_idx
    [-1] # we are only using one task per request not matter how many servers are affected
  end

  def self.affected_physical_servers(attribs)
    ids = attribs.dig('options', :src_ids)
    raise MiqException::MiqFirmwareUpdateError, 'At least one PhysicalServer is required' if ids&.empty?

    PhysicalServer.where(:id => ids).tap do |servers|
      unless servers.size == ids.size
        raise MiqException::MiqFirmwareUpdateError, 'At least one PhysicalServer is missing'
      end
      unless servers.map(&:ems_id).uniq.size == 1
        raise MiqException::MiqFirmwareUpdateError, 'All PhysicalServers need to belong to same EMS'
      end
    end
  end

  def self.affected_ems(attribs)
    affected_physical_servers(attribs).first.ext_management_system
  end

  def affected_physical_servers
    @affected_physical_servers ||= self.class.affected_physical_servers(attributes)
  end

  def affected_ems
    @affected_ems ||= self.class.affected_ems(attributes)
  end
end
