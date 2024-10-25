class PhysicalSwitch < Switch
  include SupportsFeatureMixin
  include EventMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_switches,
    :class_name => "ManageIQ::Providers::PhysicalInfraManager"

  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_one :hardware, :dependent => :destroy, :foreign_key => :switch_id, :inverse_of => :physical_switch
  has_many :physical_network_ports, :dependent => :destroy, :foreign_key => :switch_id

  # TODO: Deprecate event_streams if it makes sense, find callers, and change to use ems_events.  Even though event_streams
  # have only ever been ems_events in this model, we shouldn't rely on that, so callers should use ems_events.
  has_many :event_streams, :inverse_of => :physical_switch, :dependent => :nullify
  has_many :ems_events, :inverse_of => :physical_switch, :dependent => :nullify

  has_many :connected_components, :through => :physical_network_ports, :source => :connected_computer_system

  has_many :connected_physical_servers,
           :source_type => "PhysicalServer",
           :through     => :connected_components,
           :source      => :managed_entity

  def physical_servers
    connected_physical_servers
  end

  def physical_servers=(objects)
    self.connected_physical_servers = objects
  end

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
