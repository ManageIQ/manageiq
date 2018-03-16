class ManageIQ::Providers::Openstack::CloudManager::Provision < ::MiqProvisionCloud
  include ManageIQ::Providers::Openstack::HelperMethods
  include_concern 'Cloning'
  include_concern 'Configuration'
  include_concern 'VolumeAttachment'
end
