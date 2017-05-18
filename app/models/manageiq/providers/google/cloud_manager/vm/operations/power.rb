module ManageIQ::Providers::Google::CloudManager::Vm::Operations::Power
  extend ActiveSupport::Concern
  included do
    supports_not :suspend
  end

  def validate_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_suspend
    validate_unsupported(_("Suspend Operation"))
  end

  def raw_pause
    validate_unsupported(_("Pause Operation"))
  end

  def raw_shelve
    validate_unsupported(_("Shelve Operation"))
  end

  def raw_shelve_offload
    validate_unsupported(_("Shelve Offload Operation"))
  end

  def raw_start
    with_provider_object(&:start)
    self.update_attributes!(:raw_power_state => "starting")
  end

  def raw_stop
    with_provider_object(&:stop)
    self.update_attributes!(:raw_power_state => "stopping")
  end
end
