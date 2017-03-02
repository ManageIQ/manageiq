module ManageIQ::Providers::Redhat::InfraManager::Vm::Operations
  extend ActiveSupport::Concern

  require 'ovirt'
  include_concern 'Guest'
  include_concern 'Power'
  include_concern 'Snapshot'

  def raw_destroy
    with_provider_object(&:destroy)
  end
end
