class VdiSession < ActiveRecord::Base
  belongs_to :vdi_desktop
  belongs_to :vdi_controller
  belongs_to :vdi_user
  belongs_to :vdi_endpoint_device

  virtual_has_one   :vdi_farm
  virtual_has_one   :vdi_desktop_pool

  virtual_column :vdi_farm_name,              :type => :string,     :uses => :vdi_farm
  virtual_column :vdi_controller_name,        :type => :string,     :uses => :vdi_controller
  virtual_column :vdi_desktop_pool_name,      :type => :string,     :uses => :vdi_desktop_pool
  virtual_column :vdi_desktop_name,           :type => :string,     :uses => :vdi_desktop
  virtual_column :vdi_endpoint_device_name,   :type => :string,     :uses => :vdi_endpoint_device
  virtual_column :vdi_user_name,              :type => :string,     :uses => :vdi_user

  include ReportableMixin
  include ArCountMixin

  def vdi_farm
    get_resource_value(:vdi_controller, :vdi_farm)
  end

  def vdi_desktop_pool
    get_resource_value(:vdi_desktop, :vdi_desktop_pool)
  end

  def vdi_farm_name
    get_resource_value(:vdi_farm)
  end

  def vdi_controller_name
    get_resource_value(:vdi_controller)
  end

  def vdi_desktop_pool_name
    get_resource_value(:vdi_desktop_pool)
  end

  def vdi_desktop_name
    get_resource_value(:vdi_desktop)
  end

  def vdi_endpoint_device_name
    get_resource_value(:vdi_endpoint_device)
  end

  def vdi_user_name
    get_resource_value(:vdi_user)
  end

  def get_resource_value(rsc_type, meth = :name)
    ci = self.send(rsc_type)
    ci.nil? ? nil : ci.send(meth)
  end

  def self.event_update(event_type, props, cis)
    log_header = "MIQ(VdiSession.event_update)"

    session_state = event_type == "VdiLogoffSessionEvent" ? "LogoffSession" : props[:state]
    session = VdiSession.find_by_uid_ems(props[:session_uid])
    if session_state == "LogoffSession"
      unless session.nil?
        $log.debug "#{log_header} Deleting VDI session <#{session.uid_ems}> with state <#{session_state}>"
        session.destroy
      end
    else
      # First update or create related objects
      # Make sure the vdi desktop is pointing to the proper vm
      cis[:desktop].update_attribute(:vm_or_template_id, cis[:vm].id) if cis[:desktop] && cis[:vm]

      # Create/Update session object
      nh = {
        :encryption_level => props[:EncryptionLevel],
        :protocol         => props[:Protocol],
        :start_time       => props[:start_time],
        :state            => session_state,
        :user_name        => props[:user_name],
        :uid_ems          => props[:session_uid],
        :horizontal_resolution => props[:HorizontalResolution],
        :vertical_resolution => props[:VerticalResolution]
      }

      nh[:vdi_desktop_id]         = cis[:desktop].id         unless cis[:desktop].nil?
      nh[:vdi_controller_id]      = cis[:controller].id      unless cis[:controller].nil?
      nh[:vdi_user_id]            = cis[:user].id            unless cis[:user].nil?
      nh[:vdi_endpoint_device_id] = cis[:endpoint_device].id unless cis[:endpoint_device].nil?

      if session.nil?
        $log.debug "#{log_header} Creating VDI session with state <#{session_state}>.  Data:<#{nh.inspect}>"
        VdiSession.create(nh)
      else
        $log.debug "#{log_header} Updating VDI session <#{session.uid_ems}> with state <#{session_state}>"
        session.update_attributes(nh)
      end
    end
  end
end
