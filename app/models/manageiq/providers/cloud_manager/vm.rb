class ManageIQ::Providers::CloudManager::Vm < ::Vm
  belongs_to :availability_zone
  belongs_to :flavor
  belongs_to :orchestration_stack
  # TODO(lsmola) NetworkProvider, need to go away, but relation needs to be fixed in AWS and Azure first, then we can
  # delete the foreign keys and model these as methods returning cloud_networks.first, cloud_subnets.first
  belongs_to :cloud_network
  belongs_to :cloud_subnet
  belongs_to :cloud_tenant

  has_many :network_ports, :as => :device
  has_many :cloud_subnets, -> { distinct }, :through => :network_ports
  has_many :cloud_networks, -> { distinct }, :through => :cloud_subnets
  has_many :network_routers, -> { distinct }, :through => :cloud_subnets
  # Keeping floating_ip for backwards compatibility. Keeping association through vm_id foreign key, because of Amazon
  # ec2, it allows to associate floating ips without network ports
  has_one  :floating_ip, :foreign_key => :vm_id
  has_many :floating_ips
  has_many :security_groups, -> { distinct }, :through => :network_ports
  has_many :cloud_volumes, :through => :disks, :source => :backing, :source_type => "CloudVolume"

  has_and_belongs_to_many :key_pairs, :join_table              => :key_pairs_vms,
                                      :foreign_key             => :vm_id,
                                      :association_foreign_key => :authentication_id,
                                      :class_name              => "ManageIQ::Providers::CloudManager::AuthKeyPair"

  default_value_for :cloud, true

  virtual_column :ipaddresses,   :type => :string_set, :uses => {:network_ports => :ipaddresses}
  virtual_column :mac_addresses, :type => :string_set, :uses => :network_ports

  def ipaddresses
    @ipaddresses ||= network_ports.collect(&:ipaddresses).flatten.compact.uniq
  end

  def mac_addresses
    @mac_addresses ||= network_ports.collect(&:mac_address).compact.uniq
  end

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

  def validate_resize
    validate_unsupported(_("Resize"))
  end

  def disconnect_ems(e = nil)
    self.availability_zone = nil if e.nil? || ext_management_system == e
    super
  end

  def service
    super || orchestration_stack.try(:service)
  end

  def direct_service
    super || orchestration_stack.try(:direct_service)
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self)
  end
end
