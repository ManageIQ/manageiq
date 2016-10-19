module ManageIQ::Providers::Vmware::CloudManager::Vm::Operations
  extend ActiveSupport::Concern

  include_concern 'Power'
end
