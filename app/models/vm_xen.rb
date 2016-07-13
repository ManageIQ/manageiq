class VmXen < ManageIQ::Providers::InfraManager::Vm
  extend ActiveSupport::Concern

  included do
    supports :migrate
  end
end
