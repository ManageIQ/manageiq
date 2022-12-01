class PhysicalSwitch < Switch
  include SupportsFeatureMixin
  include EventMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_switches,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_one :hardware, :dependent => :destroy, :foreign_key => :switch_id, :inverse_of => :physical_switch
  has_many :physical_network_ports, :dependent => :destroy, :foreign_key => :switch_id
  has_many :event_streams, :inverse_of => :physical_switch, :dependent => :nullify

  has_many :connected_components, :through => :physical_network_ports, :source => :connected_computer_system

  has_many :connected_physical_servers,
           :source_type => "PhysicalServer",
           :through     => :connected_components,
           :source      => :managed_entity

  alias_attribute :physical_servers, :connected_physical_servers

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def event_where_clause(assoc = :ems_events)
    ["#{events_table_name(assoc)}.physical_switch_id = ?", id]
  end

  def self.display_name(number = 1)
    n_('Physical Switch', 'Physical Switches', number)
  end
end
