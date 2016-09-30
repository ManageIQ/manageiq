module ManageIQ::Providers::Vmware::InfraManager::Vm::Operations
  extend ActiveSupport::Concern

  include_concern 'Guest'
end
