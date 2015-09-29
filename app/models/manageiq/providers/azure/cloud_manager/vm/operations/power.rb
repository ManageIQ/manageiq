module ManageIQ::Providers::Azure::CloudManager::Vm::Operations::Power
  def validate_suspend
    validate_unsupported("Suspend Operation")
  end

  def validate_pause
    validate_unsupported("Pause Operation")
  end
end
