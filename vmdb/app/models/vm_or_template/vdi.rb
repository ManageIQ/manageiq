module VmOrTemplate::Vdi
  extend ActiveSupport::Concern

  included do
    has_one        :vdi_desktop, :dependent => :nullify

    virtual_column :vdi_available,                        :type => :boolean     # Most of the vdi virtual columns
    virtual_column :vdi_endpoint_name,                    :type => :string      # use vdi_settings, which uses
    virtual_column :vdi_endpoint_type,                    :type => :string      # registry_items, but vdi_settings
    virtual_column :vdi_endpoint_ip_address,              :type => :string      # re-queries
    virtual_column :vdi_endpoint_mac_address,             :type => :string
    virtual_column :vdi_connection_name,                  :type => :string
    virtual_column :vdi_connection_logon_server,          :type => :string
    virtual_column :vdi_connection_session_name,          :type => :string
    virtual_column :vdi_connection_remote_ip_address,     :type => :string
    virtual_column :vdi_connection_dns_name,              :type => :string
    virtual_column :vdi_connection_url,                   :type => :string
    virtual_column :vdi_connection_session_type,          :type => :string
    virtual_column :vdi_user_name,                        :type => :string
    virtual_column :vdi_user_domain,                      :type => :string
    virtual_column :vdi_user_dns_domain,                  :type => :string
    virtual_column :vdi_user_logon_time,                  :type => :string
    virtual_column :vdi_user_appdata,                     :type => :string
    virtual_column :vdi_user_home_drive,                  :type => :string
    virtual_column :vdi_user_home_share,                  :type => :string
    virtual_column :vdi_user_home_path,                   :type => :string
    virtual_column :has_active_vdi_session,               :type => :boolean
  end

  def has_active_vdi_session
    return false if self.vdi_desktop.nil?
    self.vdi_desktop.vdi_sessions.any? {|s| ['ConsoleLoggedIn', 'Connected'].include?(s.state)}
  end

  def vdi_available
    return true if self.vdi_desktop
    !self.vdi_connection_remote_ip_address.nil?
  end

  # This method is used to show the "VDI extensions" tab on the VM summary screen
  def vdi_summary_available
    !self.vdi_connection_remote_ip_address.nil?
  end

  def vdi_settings
    return @vdi_settings unless @vdi_settings.nil?
    @vdi_settings = {}
    self.registry_items.find(:all, :conditions => ["name LIKE ? or name LIKE ?", "%ManageIQInfo%", "%Citrix\\\\VirtualDesktopAgent\\\\State%"]).each {|reg| @vdi_settings[reg.value_name.to_sym] = reg.data}
    @vdi_settings
  end

  def vdi_endpoint_name
    vdi_settings[:ViewClient_Machine_Name]
  end

  def vdi_endpoint_type
    vdi_settings[:ViewClient_Machine_Name].to_s.match(/^WT0/) ? 'Wyse' : vdi_settings[:ViewClient_Type]
  end

  def vdi_endpoint_ip_address
    vdi_settings[:ViewClient_Broker_Remote_IP_Address]
  end

  def vdi_endpoint_mac_address
    vdi_settings[:ViewClient_MAC_Address]
  end

  def vdi_connection_name
    # VMware View / Citrix / XenDesktop (Not collected)
  end

  def vdi_connection_logon_server
    vdi_settings[:LOGONSERVER]
  end

  def vdi_connection_session_name
    vdi_settings[:SESSIONNAME]
  end

  def vdi_connection_remote_ip_address
    vdi_settings[:ViewClient_Broker_Remote_IP_Address]
  end

  def vdi_connection_dns_name
    vdi_settings[:LicenseServerName]
  end

  def vdi_connection_url
    vdi_settings[:ViewClient_Broker_URL]
  end

  def vdi_connection_session_type
    # Tunneled/Direct/?
    case vdi_settings[:ViewClient_Broker_Tunneled]
    when "false" then "Direct"
    when "true"  then "Tunneled"
    else vdi_settings[:ViewClient_Broker_Tunneled]
    end
  end

  def vdi_user_name
    vdi_settings[:LoggedOnUser]
  end

  def vdi_user_domain
    vdi_settings[:UserDomain]
  end

  def vdi_user_dns_domain
    vdi_settings[:USERDNSDOMAIN]
  end

  def vdi_user_logon_time
    unless vdi_settings[:vdi_user_logon_time].blank?
      Time.parse(vdi_settings[:vdi_user_logon_time])
    end
  end

  def vdi_user_connect_time
    unless vdi_settings[:vdi_user_connect_time].blank?
      Time.parse(vdi_settings[:vdi_user_connect_time])
    end
  end

  def vdi_user_appdata
    vdi_settings[:APPDATA]
  end

  def vdi_user_home_drive
    vdi_settings[:HOMEDRIVE]
  end

  def vdi_user_home_share
    vdi_settings[:HOMESHARE]
  end

  def vdi_user_home_path
    vdi_settings[:HOMEPATH]
  end

  def vdi_user_ldap
    return nil if self.vdi_user_name.nil? || !MiqLdap.using_ldap?
    upn = "#{self.vdi_user_name}@#{self.vdi_user_dns_domain}"
    l = MiqLdap.new
    if l.bind_with_default == true
      return nil if (ldap = l.get_user_info(upn, 'upn')).nil?
      result = []
      ldap.each_pair {|k,v| result << [k.to_s.titleize, v]}
      result.sort!
    else
      return nil
    end
  end
end
