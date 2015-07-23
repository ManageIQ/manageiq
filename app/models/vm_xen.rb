class VmXen < ManageIQ::Providers::InfraManager::Vm
  def validate_migrate
    validate_supported
  end
end
