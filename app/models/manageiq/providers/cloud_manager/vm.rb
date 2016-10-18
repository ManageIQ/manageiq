class ManageIQ::Providers::CloudManager::Vm < ::Vm
  belongs_to :availability_zone
  belongs_to :flavor
  belongs_to :orchestration_stack
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

  has_many :load_balancer_pool_members
  has_many :load_balancer_listeners, -> { distinct }, :through => :load_balancer_pool_members
  has_many :load_balancers, -> { distinct }, :through => :load_balancer_pool_members
  has_many :load_balancer_health_checks, -> { distinct }, :through => :load_balancer_pool_members

  has_and_belongs_to_many :key_pairs, :join_table              => :key_pairs_vms,
                                      :foreign_key             => :vm_id,
                                      :association_foreign_key => :authentication_id,
                                      :class_name              => "ManageIQ::Providers::CloudManager::AuthKeyPair"

  has_many   :host_aggregates,        :through => :host

  default_value_for :cloud, true

  virtual_column :ipaddresses, :type => :string_set, :uses => {:network_ports => :ipaddresses}
  virtual_column :floating_ip_addresses, :type => :string_set, :uses => {:network_ports => :floating_ip_addresses}
  virtual_column :fixed_ip_addresses, :type => :string_set, :uses => {:network_ports => :fixed_ip_addresses}
  virtual_column :mac_addresses, :type => :string_set, :uses => :network_ports
  virtual_column :load_balancer_health_check_state,
                 :type => :string,
                 :uses => {:load_balancer_pool_members => :load_balancer_health_check_states}
  virtual_column :load_balancer_health_check_states,
                 :type => :string_set,
                 :uses => {:load_balancer_pool_members => :load_balancer_health_check_states}
  virtual_column :load_balancer_health_check_states_with_reason,
                 :type => :string_set,
                 :uses => {:load_balancer_pool_members => :load_balancer_health_check_states_with_reason}

  def load_balancer_health_check_state
    return @health_check_state if @health_check_state
    return (@health_check_state = nil) if load_balancer_pool_members.blank?

    out_of_service_states = load_balancer_pool_members.collect(&:load_balancer_health_check_states).flatten.compact.detect do |state|
      state != 'InService'
    end

    @health_check_state = out_of_service_states.blank? ? 'InService' : 'OutOfService'
  end

  def load_balancer_health_check_states
    @health_check_states ||=
      load_balancer_pool_members.collect(&:load_balancer_health_check_states).flatten.compact
  end

  def load_balancer_health_check_states_with_reason
    @health_check_states_with_reason ||=
      load_balancer_pool_members.collect(&:load_balancer_health_check_states_with_reason).flatten.compact
  end

  def ipaddresses
    @ipaddresses ||= network_ports.collect(&:ipaddresses).flatten.compact.uniq
  end

  def floating_ip_addresses
    @floating_ip_addresses ||= network_ports.collect(&:floating_ip_addresses).flatten.compact.uniq
  end

  def fixed_ip_addresses
    @fixed_ip_addresses ||= network_ports.collect(&:fixed_ip_addresses).flatten.compact.uniq
  end

  def cloud_network
    # NetworkProvider Backwards compatibility layer with simplified architecture where VM has only one network.
    cloud_networks.first
  end

  def cloud_subnet
    # NetworkProvider Backwards compatibility layer with simplified architecture where VM has only one network.
    cloud_subnets.first
  end

  def mac_addresses
    @mac_addresses ||= network_ports.collect(&:mac_address).compact.uniq
  end

  def perf_rollup_parents(interval_name = nil)
    [availability_zone, host_aggregates].compact.flatten unless interval_name == 'realtime'
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

  def disconnect_ems(e = nil)
    self.availability_zone = nil if e.nil? || ext_management_system == e
    super
  end

  def raw_associate_floating_ip(_ip_address)
    raise NotImplementedError, _("raw_associate_floating_ip must be implemented in a subclass")
  end

  def associate_floating_ip(ip_address)
    raw_associate_floating_ip(ip_address)
  end

  def raw_disassociate_floating_ip(_ip_address)
    raise NotImplementedError, _("raw_disassociate_floating_ip must be implemented in a subclass")
  end

  def disassociate_floating_ip(ip_address)
    raw_disassociate_floating_ip(ip_address)
  end

  private

  def raise_created_event
    MiqEvent.raise_evm_event(self, "vm_create", :vm => self)
  end
end
