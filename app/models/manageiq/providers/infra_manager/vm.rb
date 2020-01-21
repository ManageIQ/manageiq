class ManageIQ::Providers::InfraManager::Vm < ::Vm
  default_value_for :cloud, false

  # Show certain non-generic charts
  def cpu_mhz_available?
    true
  end

  def memory_mb_available?
    true
  end

  def self.calculate_power_state(raw_power_state)
    return raw_power_state if raw_power_state == "wait_for_launch"
    super
  end

  def self.display_name(number = 1)
    n_('Virtual Machine', 'Virtual Machines', number)
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self, :host => host)
  end
end
