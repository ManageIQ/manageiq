class PhysicalSwitch < Switch
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_one :hardware, :dependent => :destroy, :foreign_key => :switch_id, :inverse_of => :physical_switch
  has_many :physical_network_ports, :dependent => :destroy, :foreign_key => :switch_id

  belongs_to :ext_management_system, :foreign_key => :ems_id, :inverse_of => :physical_switches

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def refresh_ems
    unless ext_management_system
      raise _("No Provider defined")
    end
    unless ext_management_system.has_credentials?
      raise _("No Provider credentials defined")
    end
    unless ext_management_system.authentication_status_ok?
      raise _("Provider failed last authentication check")
    end

    EmsRefresh.queue_refresh(ext_management_system)
  end
end
