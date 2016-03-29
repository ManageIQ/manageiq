class ManageIQ::Providers::CloudManager::Vm < ::Vm
  belongs_to :availability_zone
  belongs_to :flavor
  belongs_to :orchestration_stack
  # TODO(lsmola) NetworkProvider, need to go away, but relation needs to be fixed in AWS and Azure first, then we can
  # delete the foreign keys and model these as methods returning cloud_networks.first, cloud_subnets.first
  belongs_to :cloud_network
  belongs_to :cloud_subnet

  has_many :network_ports, :as => :device
  has_many :cloud_subnets, :through => :network_ports
  has_many :network_routers, :through => :cloud_subnets
  # Keeping floating_ip for backwards compatibility. Keeping association through vm_id foreign key, because of Amazon
  # ec2, it allows to associate floating ips without network ports
  has_one  :floating_ip, :foreign_key => :vm_id
  has_many :floating_ips

  # TODO(lsmola) NetworkProvider replace by by has_many :security_groups, :through => :network_ports, will need to be
  # implemented in all providers
  has_and_belongs_to_many :security_groups, :join_table => :security_groups_vms, :foreign_key => :vm_id
  has_and_belongs_to_many :key_pairs,       :join_table => :key_pairs_vms,       :foreign_key => :vm_id, :association_foreign_key => :authentication_id, :class_name => "ManageIQ::Providers::CloudManager::AuthKeyPair"

  default_value_for :cloud, true

  def perf_rollup_parents(interval_name = nil)
    [availability_zone].compact unless interval_name == 'realtime'
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

  def resize(new_flavor)
    raw_resize(new_flavor)
  end

  def resize_confirm
    raw_resize_confirm
  end

  def resize_revert
    raw_resize_revert
  end

  def validate_timeline
    {:available => true, :message => nil}
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self)
  end
end
