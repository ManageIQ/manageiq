class ManageIQ::Providers::Openstack::CloudManager::Provision < ::MiqProvisionCloud
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'VolumeAttachment'
end
