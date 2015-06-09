class VmCloud < Vm
  belongs_to :availability_zone
  belongs_to :flavor
  belongs_to :cloud_network
  belongs_to :cloud_subnet
  belongs_to :orchestration_stack
  has_one    :floating_ip, :foreign_key => :vm_id
  has_and_belongs_to_many :security_groups, :join_table => :security_groups_vms, :foreign_key => :vm_id
  has_and_belongs_to_many :key_pairs,       :join_table => :key_pairs_vms,       :foreign_key => :vm_id, :association_foreign_key => :authentication_id, :class_name => "AuthKeyPairCloud"

  default_value_for :cloud, true

  def perf_rollup_parents(interval_name = nil)
    [availability_zone] unless interval_name == 'realtime'
  end

  #
  # UI Button Validation Methods
  #

  def has_required_host?
    true
  end

  # Show certain non-generic charts
  def cpu_percent_available?
    true
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self)
  end
end
