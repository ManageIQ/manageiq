class PhysicalServer < ApplicationRecord
  include NewWithTypeStiMixin
  include_concern 'Operations'

  acts_as_miq_taggable
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::PhysicalInfraManager"
  has_many :firmwares, :foreign_key => "ph_server_uuid", :primary_key => "uuid"
  has_one :host, :foreign_key => "service_tag", :primary_key => "serialNumber"
  
  def name_with_details
    details % {
      :name => name,
    }
  end

  def my_zone 
    ems = ext_management_system 
    ems ? ems.my_zone : MiqServer.my_zone 
  end

  def turn_on_loc_led
    unless ext_management_system
      raise _(" A Server #{self} <%{name}> with Id:
       <%{id}> is not associated with a provider.") % {:name => name, :id => id}
    end
    verb = :turn_on_loc_led
    options = {}
    $lenovo_log.info("Send turn on LED #{self} #{verb} #{options} #{serialNumber}")
    $lenovo_log.info("Management System Name: #{ext_management_system.name}")
    ext_management_system.send(verb, self, options)
    $lenovo_log.info("Complete turn on LED #{self} #{verb} #{options}")
  end

  def turn_off_loc_led
    $lenovo_log.info("Turn off LED")
  end

  def is_refreshable?
    refreshable_status[:show]
  end

  def is_refreshable_now?
    refreshable_status[:enabled]
  end

  def is_refreshable_now_error_message
    refreshable_status[:message]
  end

  def is_available?(address)
    #TODO (walteraa) remove bypass
    true
  end

  def smart?
    #TODO (walteraa) remove bypass
    true
  end

end
