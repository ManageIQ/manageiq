class ManageIQ::Providers::Vmware::InfraManager::Provision < ::MiqProvision
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'Customization'
  include_concern 'Placement'
  include_concern 'StateMachine'

  VALID_REQUEST_TYPES = %w(template clone_to_vm clone_to_template)
  validates_inclusion_of :request_type, :in => VALID_REQUEST_TYPES, :message => "should be one of: #{VALID_REQUEST_TYPES.join(', ')}"

  def destination_type
    case request_type
    when 'template', 'clone_to_vm' then "Vm"
    when 'clone_to_template'       then "Template"
    else                                ""
    end
  end
end
