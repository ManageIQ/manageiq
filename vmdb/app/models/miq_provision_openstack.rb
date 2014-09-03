class MiqProvisionOpenstack < MiqProvisionCloud
  include_concern 'Cloning'
  include_concern 'Configuration'
end
