class VdiFarm < ActiveRecord::Base

  MGMT_ENABLED = false

  FARM_TYPES = {
    "citrix"     => "Citrix",
    "vmware"     => "VMware View",
    # "brokerless" => "Generic"    # Never released support for this type.
  }

  validates_presence_of     :name, :vendor
  validates_uniqueness_of   :name
  validates_inclusion_of    :vendor, :in => FARM_TYPES.keys

  belongs_to :zone

  has_many          :vdi_controllers, :dependent => :destroy
  has_many          :vdi_desktop_pools, :dependent => :destroy
  has_many          :miq_proxies, :dependent => :nullify

  virtual_has_many  :vdi_desktops, :uses => { :vdi_desktop_pools => :vdi_desktops }
  virtual_has_many  :vdi_users,    :uses => { :vdi_desktop_pools => :vdi_users }
  virtual_has_many  :vdi_sessions, :uses => { :vdi_desktops      => :vdi_sessions }

  include ReportableMixin
  include ArCountMixin

  def self.is_available?
    return true if VMDB::Config.new("vmdb").config.fetch_path(:product, :vdi) == true
    false
  end

  def my_zone
    zone = self.zone
    zone.nil? || zone.name.blank? ? MiqServer.my_zone : zone.name
  end
  alias zone_name my_zone

  def active_proxy
    available_proxies = self.miq_proxies.select {|p| p.is_active?}
    return available_proxies.first
  end

  def vdi_desktops
    self.vdi_desktop_pools.collect { |dp| dp.vdi_desktops }.flatten.uniq
  end

  def vdi_users
     self.vdi_desktop_pools.collect { |d| d.vdi_users }.flatten.uniq
  end

  def vdi_sessions
    self.vdi_desktops.collect { |d| d.vdi_sessions }.flatten.uniq
  end

  def has_broker?
    false
  end

  def allowed_emses
    nil
  end

  # Returns the major.minor version of a Farm/Site based on the lowest version
  # number of any of the connected controllers.
  # Returns a string in "major.minor" format or "NA" if it cannot be determined.
  def version_major_minor
    version = self.vdi_controllers.reduce(nil) {|result, c| result.nil? ? c.version.to_f : [c.version.to_f, result].min}
    return "NA" if version.nil?
    return version.to_s
  end

  def self.refresh_all_vdi_farms_timer
    zone = MiqServer.my_server.zone
    farm_ids = zone.vdi_farms.collect {|v| v.id }.compact
    self.refresh_ems(farm_ids) unless farm_ids.empty?
  end

  def self.refresh_ems(farm_ids, reload = false)
    farm_ids = farm_ids.to_miq_a
    farm_ids = farm_ids.collect { |id| [VdiFarm, id] }
    VdiRefresh.queue_refresh(farm_ids)
  end

  def refresh_ems
    proxy = self.active_proxy
    raise MiqException::Error, "No active SmartProxy found" if proxy.blank?
    VdiRefresh.queue_refresh(self)
  end

  def self.unassigned_miq_proxies
    MiqProxy.find(:all, :conditions=>["vdi_farm_id is NULL"]).select {|p| p.host && p.host.platform == 'windows'}
  end

  def process_inventory_async(binary_blob_id)
    log_header = "MIQ(VdiFarm.process_inventory_async) VdiFarm: [#{self.name}], id: [#{self.id}]"
    $log.info "#{log_header} Refreshing all targets..."

    bb = BinaryBlob.find_by_id(binary_blob_id)
    ps_object = bb.binary
    bb.destroy

    hashes = parse_raw_inv_data(ps_object)
    if hashes.blank?
      $log.warn "#{log_header} No inventory data returned for EMS: [#{@ems.name}], id: [#{@ems.id}]..."
    else
      VdiRefresh.save_vdi_inventory(self, hashes)
    end
    $log.info "#{log_header} Refreshing all targets...Complete"

    $log.info "#{log_header} Queuing post-processing"
    MiqQueue.put(
      :class_name => self.class.name,
      :instance_id => self.id,
      :method_name => "refresh_ems_post_process",
      :zone => self.my_zone
    )
  end

  def refresh_ems_post_process
    domains = self.domain_list
    Zone.find_by_name(self.my_zone).ldap_regions.each do |region|
      region.ldap_domains.each {|domain| domains << domain if domain.is_valid?}
    end

    # Try to identify and update LDAP information for users
    self.vdi_users.each do |user|
      next unless user.ldap.nil?
      user.update_record_from_ldap(nil, domains)
    end
    nil
  end

  def domain_list
    domains = []
    Zone.find_by_name(self.my_zone).ldap_regions.each do |region|
      region.ldap_domains.each {|domain| domains << domain if domain.is_valid?}
    end
    domains
  end

  def parse_raw_inv_data(ps_object)
    inv_klass = self.inventory_class
    ps_xml_str = MiqProxy.process_powershell_object(ps_object)
    ps_xml = MiqXml.load(ps_xml_str)
    vdi_ems_data = MiqPowerShell.ps_xml_to_hash(ps_xml).first
    inv_klass.to_inv_h(vdi_ems_data)
  end

  def send_ps_task(task_description, task_name, *args)
    log_header = "MIQ(VdiFarm.send_ps_task) VdiFarm: [#{self.name}], id: [#{self.id}]"

    task = MiqTask.create(:name => task_description, :userid => User.current_userid || 'system')

    $log.info("#{log_header} Queuing powershell command for: #{task_description}")
    timeout = 5.minutes.to_i_with_method
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name => self.class.name,
      :instance_id => self.id,
      :args => [task.id, task_name, *args],
      :method_name => "send_ps_task_from_queue",
      :miq_callback => cb,
      :msg_timeout => timeout,
      :zone => self.my_zone
    )
    task.state_queued
  end

  def send_ps_task_from_queue(taskid, task_name, *args)
    begin
      task = MiqTask.find_by_id(taskid) unless taskid.nil?
      task.state_active

      svc_klass = self.service_class
      svc = svc_klass.new(:plugin_version => self.version_major_minor)
      ps_script = svc.send(task_name, *args)
      my_proxy = self.active_proxy
      raise MiqException::Error, "There are no active proxies available to process this task: <#{task_name}>" if my_proxy.nil?
      task.update_message("Running command")
      result = my_proxy.powershell_command(ps_script)
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Command Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def create_tracking_task(task_description)
    task = MiqTask.create(:name => task_description, :userid => User.current_userid || 'system')
    task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Command Complete")
  end

  def self.add_event(event, host)
    # Identify the farm this event belongs to
    proxy = host.miq_proxy
    proxy.vdi_farm.add_event(event) if proxy && proxy.vdi_farm
  end

  def normalize_event_data(event_obj)
    sd = event_obj.fetch_path(:session, :Props) || event_obj.fetch_path(:session, :MS) || event_obj.fetch_path(:session, :Obj, :MS)
    return event_obj if sd.nil?

    # convert key names to common names
    {
      :desktop_pool_name => [:GroupId,  :pool_id],
      :desktop_name      => [:DesktopName],
      :user_name         => [:UserName, :Username],
      :controller_name   => [:Controller],
      :start_time        => [:StartTime, :startTime],
      :endpoint_name     => [:EndpointName],
      :UserSid           => [:UserSID],
      :State             => [:SessionState]
    }.each {|k,v| v.each {|key| sd[k] = sd.delete(key) if sd.has_key?(key)}}

    if event_obj[:source].include?('citrix')
      sd[:session_uid] = "#{sd[:start_time].to_i}_#{sd[:desktop_name]}"
      sd[:state]       = sd.fetch_path(:State, :ToString)

      # Citrix v5 specific normalization
      normalize_citrix_v5_data(event_obj, sd) if event_obj[:plugin_version].to_i >= 5
    elsif event_obj[:source].include?('vmware')
      sd[:desktop_name] = event_obj.fetch_path(:desktop, :MS, :Name) || event_obj.fetch_path(:desktop, :Obj, :MS, :Name)
      sd[:session_uid]  = sd.delete(:session_id).to_s[0,255]
    end

    # Get UserSid out of session_uid (VMware View)
    if sd[:UserSid].blank?
      regex_user = sd[:user_name].to_s.split('\\').last
      usersid_regex = Regexp.new("#{regex_user}\\(cn=(S-\\d-\\d-\\d{2}-\\d{10}-\\d{10}-\\d{10}-\\d{4})", Regexp::IGNORECASE)
      sd[:UserSid].to_s.upcase = $1 if sd[:session_uid] =~ usersid_regex
    end

    event_obj
  end

  def normalize_citrix_v5_data(event_obj, sd)
    sd[:controller_name] = sd[:LaunchedViaHostName]
    sd[:session_uid] = "#{sd[:start_time].to_i}_#{sd[:DesktopUid]}"

    if sd[:state].to_s.downcase.include?('nonbrokered')
      # This indicates a session not going through the VDI broker.  Likely a direct RDP session.
      sd[:endpoint_name]   = sd[:ConnectedViaHostName]
      sd[:EndpointName]    = sd[:ConnectedViaHostName]
      sd[:EndpointAddress] = sd[:ConnectedViaIP]
      sd[:EndpointId]      = sd[:ConnectedViaIP]
    else
      # In v5 controller name is stored in the LaunchedViaHostName field for some sessions
      sd[:controller_name] = sd[:LaunchedViaHostName]
      if sd[:ConnectedViaHostName].blank?
        sd[:EndpointName]    = sd[:ClientName]
        sd[:EndpointAddress] = sd[:ClientAddress]
      else
        sd[:EndpointName]    = sd[:ConnectedViaHostName]
        sd[:EndpointAddress] = sd[:ConnectedViaIP]
      end
      sd[:EndpointId]      = sd[:HardwareId]
      sd[:endpoint_name]   = sd[:EndpointName]

      # User BrokeringUserName if user_name is blank
      if sd[:user_name].blank? && !sd[:BrokeringUserName].blank?
        sd[:user_name] = sd[:BrokeringUserName]
        sd[:UserSid]  = sd[:BrokeringUserSID]
      end
    end
  end

  def add_event(event_hash)
    event_obj = event_hash[:ps_event]
    event_source = event_obj[:source] || 'EVM'
    timestamp = event_obj.fetch_path(:time, :DT) || Time.now
    timestamp = timestamp.utc.iso8601
    event_type = event_obj[:type]
    event_message = event_type

    normalize_event_data(event_obj)
    vm = VdiDesktop.find_vm_for_uid_ems(event_obj)
    # Load full VM
    vm = VmOrTemplate.find_by_id(vm.id) unless vm.nil?
    event = {
      :event_type =>  event_type,
      :is_task =>     false,
      :source =>      event_source,
      :message =>     event_message,
      :timestamp =>   timestamp,
      :full_data   => event_obj
    }

    unless vm.nil?
      event.merge!({
        :vm_or_template_id => vm.id,
        :vm_name           => vm.name,
        :vm_location       => vm.path,
      })

      event[:ems_id] = vm.ems_id unless vm.ems_id.nil?

      unless vm.host_id.nil?
        event[:host_id] = vm.host_id
        event[:host_name] = vm.host.name
      end
    end

    session_data = event_obj.fetch_path(:session, :Props) || event_obj.fetch_path(:session, :MS) || event_obj.fetch_path(:session, :Obj, :MS)
    unless session_data.nil?
      controller_name = session_data[:controller_name]
      unless controller_name.nil?
        event[:vdi_controller_name] = controller_name
        c_name = controller_name.downcase
        controller = self.vdi_controllers.detect {|c| c.name.to_s.downcase == c_name}
        event[:vdi_controller_id] = controller.id unless controller.nil?
      end

      dp, desktop = nil
      desktop_pool_uid = session_data[:desktop_pool_name]
      unless desktop_pool_uid.nil?
        dp = VdiDesktopPool.find_by_uid_ems(desktop_pool_uid)
        unless dp.nil?
          event[:vdi_desktop_pool_id] = dp.id
          event[:vdi_desktop_pool_name] = dp.name

          desktop_name = session_data[:desktop_name]
          unless desktop_name.nil?
            event[:vdi_desktop_name] = desktop_name
            desktop = VdiDesktop.find_by_name_and_vdi_desktop_pool_id(desktop_name, dp.id)
            event[:vdi_desktop_id] = desktop.id unless desktop.nil?
          end
        end
      end

      user_name = session_data[:user_name]
      unless user_name.nil?
        event[:vdi_user_name] = user_name
        user = VdiUser.find_by_name(user_name)
        # Create vdi user
        if user.nil? && (session_data[:UserSid] && session_data[:user_name])
          user = VdiUser.create(:uid_ems=>session_data[:UserSid], :name=>session_data[:user_name])
        end
        event[:vdi_user_id] = user.id unless user.nil?

        unless user.nil?
          unless dp.nil?
            dp.vdi_users << user unless dp.vdi_users.any? {|u| u.uid_ems == user.uid_ems}
          end

          desktop.vdi_users << user unless desktop.nil?

          event[:vdi_user_id] = user.id
        end
      end

      endpoint_name = session_data[:endpoint_name]
      unless endpoint_name.nil?
        event[:vdi_endpoint_device_name] = endpoint_name
        endpoint_id = session_data[:EndpointId]
        endpoint_device = VdiEndpointDevice.find_by_uid_ems(endpoint_id)

        # Create or update vdi endpoint device
        nh = {:name=>session_data[:endpoint_name], :ipaddress=>session_data[:EndpointAddress], :uid_ems=>session_data[:EndpointId]}
        if endpoint_device.nil?
          endpoint_device = VdiEndpointDevice.create(nh)
        else
          endpoint_device.update_attributes(nh)
        end
        event[:vdi_endpoint_device_id] = endpoint_device.id
      end

      case event[:event_type]
      when "VdiLoginSessionEvent", "VdiConsoleLoggedInSessionEvent"
        event[:message] = "User #{event[:vdi_user_name]} logged into Desktop #{event[:vdi_desktop_name]} from Endpoint Device #{event[:vdi_endpoint_device_name]}"
      when "VdiLogoffSessionEvent"
        event[:message] = "User #{event[:vdi_user_name]} logged off Desktop #{event[:vdi_desktop_name]}."
      when "VdiConnectingSessionEvent"
        event[:message] = "User #{event[:vdi_user_name]} initiated a connection to Desktop #{event[:vdi_desktop_name]}"
      when "VdiDisconnectedSessionEvent"
        event[:message] = "User #{event[:vdi_user_name]} disconnected from Desktop #{event[:vdi_desktop_name]}"
      end

      # Create or Update session object
      VdiSession.event_update(event[:event_type], session_data,
                              {:vm              => vm,
                               :controller      => controller,
                               :desktop_pool    => dp,
                               :desktop         => desktop,
                               :user            => user,
                               :endpoint_device => endpoint_device
                              })

      EmsEvent.add(vm.ems_id, event) unless vm.nil?
    end
  end
end
