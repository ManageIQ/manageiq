class PhysicalServerProvisionTask < MiqProvisionTask
  include_concern 'StateMachine'

  def description
    'Provision Physical Server'
  end

  def self.base_model
    PhysicalServerProvisionTask
  end

  def self.request_class
    PhysicalServerProvisionRequest
  end

  def model_class
    PhysicalServer
  end

  def deliver_to_automate
    super('physical_server_provision', my_zone)
  end
end
