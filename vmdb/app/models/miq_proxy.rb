require 'miq-system'
require 'MiqSockUtil'
$:.push(File.expand_path(File.join(Rails.root, %w{.. lib Verbs implementations})))
$:.push(File.expand_path(File.join(Rails.root, %w{.. lib util win32})))

MIQHOST_PRODUCT_NAME = "SmartProxy"
MIN_LINUX_MB = 300

class MiqProxy < ActiveRecord::Base
  validates_presence_of :name
  belongs_to  :host
  belongs_to  :vm
  has_many    :proxy_tasks
  has_many :log_files, :dependent => :destroy, :as => :resource
  has_and_belongs_to_many :product_updates

  serialize   :settings
  serialize   :capabilities
  serialize   :remote_config
  serialize   :upgrade_settings

  default_value_for :version,  "N/A"
  default_value_for(:settings) { MiqProxy.agent_config_settings }

  acts_as_miq_taggable
  include ReportableMixin

  virtual_column :v_arch, :type => :string

  include UuidMixin

  @@host_ws_tasks = Array.new

  HEARTBEAT_GRACE_PERIOD = 120

  def self.agent_config_settings
    VMDB::Config.new("hostdefaults").get(:agent)
  end

  after_find do
    #TODO: Can this be replaced somehow, perhaps on the getter?
    defaults = MiqProxy.agent_config_settings
    if self.attributes.include?('settings')
      if self.settings.nil?
        self.settings = defaults
      else
        self.settings = defaults.merge(self.settings) unless defaults.nil?
      end
    end
  end

  def address
    contact_with = VMDB::Config.new("vmdb").config.fetch_path(:webservices, :contactwith)
    contact_with == 'hostname' ? self.host.hostname : self.host.ipaddress
  end

  # What MiqVerbs accepts
  def self.normalize_method_name(name)
    case name.to_sym
    when :vm_start;           return 'StartVM'
    when :vm_stop;            return 'StopVM'
    when :vm_suspend;         return 'SuspendVM'
    when :vm_pause;           return 'PauseVM'
    when :vm_reset;           return 'reset'
    when :vm_reboot_guest;    return 'rebootGuest'
    when :vm_sync_metadata;   return 'SyncMetadata'
    when :vm_scan_metadata;   return 'ScanMetadata'
    when :vm_create_snapshot; return 'CreateSnapshot'
    end

    return name
  end

  def call_ws(ost)
    config = VMDB::Config.new("vmdb").config[:webservices]

    self.host.resolve_hostname! if config[:nameresolution]

    ost.host = self.address
    ost.port = self.myport
    ost.hostId = self.host.guid
    ost.method_name = self.class.normalize_method_name(ost.method_name)

    # If host ws are disabled, add the command to the queue of things that "should be run"
    if config[:mode] == "disable" || ost.useHostQueue == true
      @@host_ws_tasks << ost
      $log.info "MIQ(proxy-call_ws): Task queued [#{@@host_ws_tasks.length}]: [#{ost.marshal_dump.inspect}]"
      ost2 = ost.clone
      miqcmd_formatter
      #WakeupHost(ost2) # This call needs to be threaded to avoid waiting for a timeout if the host is not reachable.
      return "queued"
    end

    $log.info "MIQ(proxy-call_ws): Calling: [#{ost.marshal_dump.inspect}]"
    # This call to the web-service layer was changed from "call" to "send" to see if it resolves
    # issues with random "Insecure operation" errors.
    #ret = WebSvcOps.new(ost).method(ost.method_name).call(ost)
    require 'WebSvcOps'
    begin
      # set timeout values
      timeout = config[:timeout] || 120
      ost.connect_timeout = timeout
      ost.send_timeout    = timeout
      ost.receive_timeout = timeout

      ws = WebSvcOps.new(ost)
      ret = ws.send(ost.method_name.to_sym, ost)
      $log.info "MIQ(proxy-call_ws): Method: [#{ost.method_name}] returned: [#{ret}]"
      return ret
    rescue TimeoutError
      $log.error "MIQ(proxy-call_ws): Error: web service call timed out"
      raise
    rescue => err
      $log.log_backtrace(err)
      raise
    end
  end

  def myport
    return self.ws_port unless self.ws_port.blank?
    self.settings[:wsListenPort]
  end

  # Return the architecture of the ruby process running the proxy (miqhost)
  # This does not neccessarily mean the architecture of the Host hardware or OS.
  # For example the host could be x86_64 with an x86 miqhost proxy.
  def arch
    return self.remote_config[:host_arch].to_s rescue "unknown"
  end
  alias v_arch arch

  def my_zone
    self.host.my_zone
  end

  def self.proxies_by_zone(zone = 'default')
    # find the proxies with that zone, return array of proxies
    self.find(:all, :include => :host).map {|p| p if p.host.my_zone.to_s.downcase == zone.downcase}.compact
  end

  def agent_config(agentCfg)
    # This call will raise an error if problems are detected with the config settings
    [agentCfg, "agentCfg", self.settings.inspect, "settings"].each_slice(2) { |c,n| validate_config(c,n) }

    #Update host version for agent settings
    unless agentCfg[:host_version].nil?
      self.version = agentCfg[:host_version].join(".")
      self.link_to_current_update()
    end

    unless agentCfg[:wsListenPort].blank?
      self.ws_port = agentCfg[:wsListenPort]
    end

    unless self.upgrade_settings.nil?
      unless self.upgrade_settings[:version].nil?
        task = MiqTask.find(self.upgrade_settings[:taskid])  unless self.upgrade_settings[:taskid].nil?
        if task
          if self.upgrade_settings[:version] == self.version
            msg = "Successfully updated the SmartProxy version to [#{self.version}]"
            $log.info msg
            task.update_status("Finished", "Ok", msg)
          else
            msg = "Failed to update the SmartProxy build to [#{self.upgrade_settings[:version]}].  Running Version:[#{self.version}]"
            $log.warn msg
            task.update_status("Finished", "Warn", msg)
          end
        end
      end
      self.upgrade_settings = nil
    end

    # Store the config sent from miqhost for reference
    self.remote_config = agentCfg
    self.save

    same = true
    self.settings.each_key {|key|
      # cases:
      if agentCfg.keys.include?(key)
        # key exists in both hashes
        same = false if agentCfg[key] != self.settings[key]
      else
        # key exists in vmdb but not in agent
        same = false
      end
    }

    agentCfg.each_key {|key|
      if !self.settings.keys.include?(key)
        # key exists in agent but not in vmdb
        #   Not worrying about this now
      end
    }

    # Here we want to update what capabilities the proxy provides
    update_capabilities(agentCfg[:capabilities])

    # Check if the agent sent ems local settings and add if needed
    same = false if check_ems_local_settings(agentCfg)

    if same
      # Since we get data from ems now we do not need to make these calls
      #
      # Request data about the host if it does not have any VMs
      if self.host.platform == "windows" && self.host.vms.size.zero?
        refresh_host_commands.each do |cmd|
          MiqQueue.put(
            :target_id => self.host.id,
            :class_name => "Host",
            :method_name => "call_ws_from_queue",
            :data => Marshal.dump(cmd),
            :priority => MiqQueue::HIGH_PRIORITY
          )
        end
      end
      true   # return true for no changes
    else
      # Since we are sending down the Agent Config settings here remove
      # any pending calls from the proxies heartbeat queue.
      removePendingTasks("ChangeAgentConfig")
      self.settings
    end
  end

  def link_to_current_update()
    begin
      cp = self.host.available_builds.detect {|b| self.version == "#{b.version}.#{b.build}"}
      return self.product_updates.delete_all if cp.nil?
      if cp != self.product_updates
        self.product_updates.delete_all
        self.product_updates << cp
      end
    rescue
    end
  end

  def check_ems_local_settings(agentCfg)
    # Check for ems local settings on VMware linux ESX boxes
    default_key = 'auto-local'
    agentCfg[:ems] ||= Hash.new
    updated = false

    if self.host.vmm_product.to_s.downcase.include?("esx")
      # We need to have userid and password configured for the host for this to work.
      if self.host.authentication_valid?(:ws)
        if agentCfg[:emsLocal].blank?
          self.settings[:emsLocal]=default_key
          updated = true
        end
        updated = true if self.update_ems_local_settings(agentCfg, default_key, :ws, 'vmwarewws') == true
      end
    elsif ['KVM'].include?(self.host.vmm_vendor)
      agentCfg[:emsEventMonitor] ||= []
      has_default_key = agentCfg[:emsEventMonitor].include?(default_key)
      if self.eventing_enabled == true && !has_default_key
        agentCfg[:emsEventMonitor] << default_key
        self.settings[:emsEventMonitor] = agentCfg[:emsEventMonitor]
        updated = true
      elsif self.eventing_enabled == false && has_default_key
        agentCfg[:emsEventMonitor].delete(default_key)
        self.settings[:emsEventMonitor] = agentCfg[:emsEventMonitor]
        updated = true
      end
      updated = true if self.update_ems_local_settings(agentCfg, default_key, :default, 'local') == true
    end

    return updated
  end

  def update_ems_local_settings(agentCfg, key_name, auth_type, type)
    host = self.host
    # If the local ems setting is blank or not configured set it
    if !agentCfg[:ems].has_key?(key_name)
      self.settings[:ems] = agentCfg[:ems]

      # Send down the required emslocal setting.
      self.settings[:ems][key_name] = {"type"=>type, "host"=>"127.0.0.1", "user"=>host.authentication_userid(auth_type), "password"=>host.authentication_password_encrypted(auth_type)}
      return true
    else
      autoLocal = agentCfg[:ems][key_name]

      if autoLocal["user"] != host.authentication_userid(auth_type) || autoLocal["password"] != host.authentication_password_encrypted(auth_type)
        autoLocal["user"] = host.authentication_userid(auth_type)
        autoLocal["password"] = host.authentication_password_encrypted(auth_type)
        self.settings[:ems] = agentCfg[:ems]
        return true
      end
    end
    return false
  end

  def update_capabilities(proxy_capabilities)
    if proxy_capabilities.is_a?(Hash)
      self.capabilities = proxy_capabilities

      # If vixDisk is enabled we need to set the host to do the snapshot
      self.settings[:forceFleeceDefault] = true if self.capabilities[:vixDisk]

      self.save
    end
  end

  def removePendingTasks(task_name)
    self.proxy_tasks.each do |t|
      t.destroy if t[:state] == "pending" && t[:command][:method_name] == task_name
    end
  end

  def validate_config(config, name)
    begin
      # The 'inspect' call will throw an error if one of the config elements is bad
      $log.debug "MIQ(proxy-validate_config): #{name}=<#{config.inspect}>"
    rescue => err
      errMsg = "Error detected during inspect of [#{name}] object.  Message:[#{err}]"
      $log.error "MIQ(proxy-validate_config): " + errMsg
      config.each_pair do |k,v|
        begin
          k;  v.inspect
        rescue => err
          errMsg = "Error evaluating config parameter [#{k}] for [#{name}].  Message:[#{err}]"
          $log.error "MIQ(proxy-validate_config): " + errMsg
        end
      end
      raise errMsg
    end
  end

  def self.notify_server_ip_change(new_ip)
    new_opts = { :vmdbHost => new_ip, :useHostQueue => false }
    MiqProxy.find(:all).each { |p| p.change_agent_config(new_opts) }
  end

  def clear_queue_items(options={})
    options.reverse_merge!({:task_id=>nil, :queue_name=>nil})
    call_ws(OpenStruct.new("method_name"=>"ClearQueueItems", "options"=>YAML.dump(options)))
  end

  def restart
    shutdown(true)
  end

  def shutdown(restart=false)
    call_ws(OpenStruct.new("method_name"=>"Shutdown", "options"=>YAML.dump({:restart=>restart})))
  end

  def change_agent_config(opts=nil)
    config = self.settings
    config.merge!(opts) unless opts.nil?

    useHostQueue = config.delete(:useHostQueue)
    useHostQueue = true if useHostQueue.nil?

    # Only the most recent Config settings need to be on the queue so
    # remove any pending calls from the proxies heartbeat queue.
    removePendingTasks("ChangeAgentConfig")
    call_ws(OpenStruct.new("method_name"=>"ChangeAgentConfig", "config"=>YAML.dump(config), "useHostQueue"=>useHostQueue))
  end

  def update_power_state_proxy(new_state)
    if self.power_state != new_state
      # If the power state is "unknown" it is when the state is being checked before it has been set.
      # In this case skip logging it to avoid logging a confusing message.
      unless new_state == "unknown"
        $log.info "MIQ(proxy-heartbeat): Smart host [#{self.name}], guid:[#{self.guid}] power state has changed from [#{self.power_state }] to [#{new_state}]"
      end
      self.power_state = new_state
      return true
    end
    return false
  end

  def heartbeat(xmlDoc, type)
    xmlDoc = MIQEncode.decode(xmlDoc)
    xmlDoc = MiqXml.load(xmlDoc)
    $log.debug "MIQ(proxy-heartbeat): queue count = [#{self.proxy_tasks.size.to_s}]"
    $log.debug "MIQ(proxy-heartbeat): XML IN: [#{xmlDoc.to_s}]"

    # Extract the agent's time from the suppied xml
    is_exiting, current_tasks = false, nil
    timeNode = xmlDoc.find_first("//host[@agent_time]")
    if timeNode
      @agentTime = Time.parse(timeNode.attributes['agent_time'])
      agentHostname = timeNode.attributes['hostname']
      is_exiting = YAML.load(timeNode.attributes['exiting'].to_s)
      current_tasks = YAML.load(timeNode.attributes['tasks'].to_s)
    end

    # Make sure current_tasks is an array
    current_tasks = [] unless current_tasks.is_a?(Array)

    $log.info "MIQ(proxy-heartbeat): hostId:[#{self.host.id}]  Hostname:[#{agentHostname}]  SmartProxy time:[#{@agentTime.nil? ? "unknown" : @agentTime.iso8601}]  Host GUID:[#{self.host.guid}]  Remote Tasks Count:[#{current_tasks.length}]  Exiting?:[#{is_exiting}]"
    # Mark that we got a heartbeat

    if is_exiting
      self.last_heartbeat = Time.now.utc - HEARTBEAT_GRACE_PERIOD - self.settings[:heartbeat_frequency]
      self.update_power_state_proxy("off")
    else
      self.last_heartbeat = Time.now.utc
      self.update_power_state_proxy("on")
    end

    unless current_tasks.empty?
      MiqQueue.put(
        :target_id => self.host.id,
        :class_name => "Job",
        :method_name => "extend_timeout",
        :data => Marshal.dump(current_tasks),
        :priority => MiqQueue::HIGH_PRIORITY
      )
    end

    # Update the host with the version
    xmlDoc.find_match("//host").each { |n| self.version = n.attributes["version"] if n.attributes["version"] }
    self.save!

    # Now look for pending host tasks to send to the agent.
    tasks = []

    unless is_exiting
      self.proxy_tasks.each do |t|
        task = t[:command]
        tasks << YAML.dump(task)
        t.destroy
        break
      end
    end

    return {:server_message=>"OK", :hostId=>self.host.guid, :tasks=>tasks}
  end

  def scan(scanLoc=nil)
    if scanLoc.is_a?(Repository)
      scan_repository(scanLoc)
    else
      refresh_host_commands.each {|cmd| call_ws(OpenStruct.new(cmd))}
    end
  end

  def refresh_host_commands
    if self.host.acts_as_ems?
      return [{"method_name"=>"GetEmsInventory"}]
    else
      return [{"method_name"=>"GetHostConfig"}, {"fmt"=>true, "method_name"=>"GetVMs"}]
    end
  end

  def scan_repository(repository)
    call_ws(OpenStruct.new("method_name"=>"ScanRepository", "repository_id"=>repository.id, "path"=>repository.path, "fmt"=>true))
  end

  def delete_blackbox
    call_ws(OpenStruct.new("args"=>[], "deleteall"=>true, "method_name"=>"DeleteBlackBox"))
  end

  # Ask host to update all locally registered vm state data
  def refresh_vm_state
    begin
      ost = OpenStruct.new("method_name"=>"SendVMState")
      call_ws(ost)
    rescue Exception => err
      $log.log_backtrace(err)
    end
  end

  def miqcmd_formatter
    begin
      while @@host_ws_tasks.empty? == false
        cmd = @@host_ws_tasks.shift
        cmd_hash = cmd.marshal_dump
        $log.debug "MIQ(proxy-miqcmd_formatter): #{cmd_hash.inspect}"
        # Remove items before queuing task
        cmd_hash.delete(:host);cmd_hash.delete(:port)
        x = self.proxy_tasks.create({:command=>cmd_hash, :state=>"pending"})
        x.save!
      end
    rescue => err
      $log.log_backtrace(err)
    end
  end

  def WakeupHost(ost=nil)
    require 'WebSvcOps'
    begin
      ost = OpenStruct.new("host"=>self.address, "port"=>self.myport, "hostId"=>self.host.guid) if ost.nil?
      ost.method_name = "WakeupHeartbeat"
      #WebSvcOps.new(ost).method(ost.method_name).call(ost)
      ws = WebSvcOps.new(ost)
      ws.send(ost.method_name, ost)
    rescue
    end
  end

  def build_number
    return nil if self.version.blank?
    self.version.split(".").last
  end

  def at_latest_build?
    latest = self.host.available_builds.sort.last
    current = self.version.blank? ? "unknown" : self.version.split(".").last

    if latest == current
      return [true, "SmartProxy version #{current} is up to date"]
    elsif latest > current
      return [false, "SmartProxy version is #{current} but should be at version #{latest}"]
    elsif current == "unknown"
      return [false, "SmartProxy version is unknown"]
    else
      return [false, "SmartProxy version is out of sync, SmartProxy version is #{current} but latest version is #{latest}"]
    end
  end

  def get_agent_logs(options={})
    options = { :collect => 'all' }.merge(options)
    url = "/agent/log"

    # If we have agent logs already, only request newer logs
    flist = sorted_log_list()
    options[:lastUploadTime] = flist.last[1].to_i unless flist.empty?

    call_ws(OpenStruct.new("method_name"=>"GetAgentLogs", "url"=>url, "options"=>options.inspect))
  end

  def local_log_files
    Dir.glob(File.join(self.logdir, "*.log"))
  end

  def sorted_log_list
    files = {}
    self.local_log_files.each {|name| files[name] = File.mtime(name)}
    files.sort {|a,b| a[1]<=>b[1]}
  end

  def log_contents(width=nil, last=1000)
    data = ""
    # Get the list of available logs
    flist = sorted_log_list()
    # Reverse this list so the newest logs are processed first
    flist.reverse!
    # Add log lines to the "data" array until we have the requested amount of lines (last).
    remaining = last
    data = []
    flist.each {|name, date|
      lines, length = _log_contents(name, remaining, width)
      data = lines + data
      remaining = remaining - length
      break if remaining == 0
    }
    data.join("\n")
  end

  def _log_contents(file, last, width=nil)
    return unless File.file?(file)

    contents = MiqSystem.tail(file, last)
    content_length = contents.length

    results = []
    contents.each {|line|
      while !width.nil? && line.length > width
        results.push(line[0..width-1])
        line = line[width..line.length]
      end
      results.push(line) if line.length
    }
    [results, content_length]
  end

  def logdir
    logdir = File.join(File.expand_path(Rails.root))
    ["data", "host", self.id.to_s, "log"].each {|part|
      logdir = File.join(logdir, part)
      Dir.mkdir logdir unless File.exists?(logdir)
    }
    return logdir
  end

  def zip_logs(userid = "system", fname = "SmartHost_logs_#{self.host.hostname}.zip")
    VMDB::Util.zip_logs(fname, [self.logdir + "/*.log"], userid)
  end

  def state
    # Set the default current_state for the Host to "unknown"
    current_state = "unknown"

    # If the host has ever sent a heartbeat, set the current_state based off
    # of the heartbeat
    unless self.last_heartbeat.nil?
      last_heartbeat = self.last_heartbeat
      last_heartbeat ||= Time.at 0

      threshold = self.settings[:heartbeat_frequency] + HEARTBEAT_GRACE_PERIOD

      # if the last_heartbeat is within the threshold, set the current state on
      current_state = (threshold.seconds.ago.utc < last_heartbeat) ? "on" : "off"
    end
    self.save if self.update_power_state_proxy(current_state)
    current_state
  end

  def started?
    # Make proxy respond_to the started? method like the MiqServer
    self.state == 'on'
  end

  def who_am_i
    @who_am_i ||= "#{self.name} #{self.class.name} #{self.id}"
  end

  def _post_my_logs(options)
    # Set the queue callback to only update status if not "ok" (error/warn/timeout)
    # since post_my_logs does not complete the log posting... we need to wait until the Proxy has uploaded all his logs
    options[:callback][:method_name] = :queue_callback_on_exceptions

    # Make the request to the proxy from a MiqServer in the Proxy's zone
    MiqQueue.put({
        :class_name => self.class.name,
        :instance_id => self.id,
        :method_name => "post_my_logs",
        :args => [options[:taskid]],
        :priority => MiqQueue::HIGH_PRIORITY,
        :zone => self.my_zone,
        :miq_callback => options[:callback],
        :msg_timeout => options[:timeout]
      })
  end

  def post_my_logs(taskid)
    resource = who_am_i
    task = MiqTask.find(taskid)
    log_header = "MIQ(#{self.class.name}-post_my_logs) Task: [#{taskid}]"
    msg = "Requesting logs for: #{resource}"
    $log.info("#{log_header} #{msg}")
    task.update_status("Active", "Ok", msg)

    # Remove the most recent log so we can fetch any updates in the file
    flist = sorted_log_list()
    File.delete(flist.last[0]) if !flist.empty? && File.exists?(flist.last[0])

    # Make the request to the proxy for the logs and go away.  Upon final log upload, post_zip_to_db will be called
    ret = get_agent_logs("taskid" => task.id)

    if ret
      msg = "Finished requesting logs from: #{resource}"
      $log.info("#{log_header} #{msg}")
      task.update_status("Active", "Ok", msg)
    end
  end

  def post_zip_to_db(taskid)
    # will be called from the agent controller when the final logfile has been saved locally
    task = MiqTask.find(taskid)

    # We need to setup the callback through the queue in case something blows up
    cb = {:class_name => task.class.name, :instance_id => taskid, :method_name => :queue_callback, :args => ['Finished']}

    # Make sure that the server that ran this method is the one who picks up the queue item
    # since it has the uploaded proxy logs.
    # TODO: remove this queue call and update the task appropriately
    MiqQueue.put({
        :class_name => self.class.name,
        :instance_id => self.id,
        :method_name => "post_zip_to_db_in_queue",
        :args => [taskid],
        :priority => MiqQueue::HIGH_PRIORITY,
        :zone => self.my_zone,
        :miq_callback => cb,
        :server_guid => MiqServer.my_guid,
        :msg_timeout => LogFile.log_request_timeout
      })
    log_header = "MIQ(#{self.class.name}-post_zip_to_db) Task: [#{taskid}]"
    resource = who_am_i
    msg = "Queued the posting of the combined zip file for: #{resource}"
    $log.info("#{log_header} #{msg}")
    task.update_status("Active", "Ok", msg)
  end

  def post_zip_to_db_in_queue(taskid)
    resource = who_am_i
    task = MiqTask.find(taskid)
    log_header = "MIQ(#{self.class.name}-post_zip_to_db_in_queue) Task: [#{task.id}]"
    msg = "Posting logs for: #{resource}"
    $log.info("#{log_header} #{msg}")
    task.update_status("Active", "Ok", msg)

    base = "#{self.class.name}_#{self.id}" + ".zip"
    file = self.zip_logs("system", base)
    log = LogFile.create(:name => base, :description => "Log files from #{resource}", :miq_task_id => task.id, :local_file => file)
    self.log_files << log
    self.save
    log.upload
    File.delete(file) if File.exists?(file)

    msg = "Log files from #{resource} are posted"
    $log.info("#{log_header} #{msg}")
    task.update_status("Finished", "Ok", msg)
  end

  def hosts
    self.storages.collect {|s| s.hosts}.flatten.compact.push(self.host).uniq
  end

  def vms
    self.storages.collect {|s| s.vms}.flatten.compact.uniq
  end

  def miq_templates
    self.storages.collect {|s| s.miq_templates}.flatten.compact.uniq
  end

  def storages
    return [] if self.host.nil?
    self.host.storages
  end

  def ext_management_system
    return nil if self.host.nil?
    self.host.ext_management_system
  end

  def concurrent_job_max
    # SmartProxies by default only support 1 current job at a time
    1
  end

  # settings hash methods
  def set(key, value=nil)
    self.settings[key] = value unless value == nil
    self.settings[key]
  end

  def heartbeat_frequency
    self.settings[:heartbeat_frequency]
  end

  def heartbeat_frequency=(switch)
    self.settings[:heartbeat_frequency] = switch
  end

  def scan_frequency
    self.settings[:scan_frequency]
  end
  def scan_frequency=(switch)
    self.settings[:scan_frequency] = switch
  end

  def update_frequency
    self.settings[:update_frequency]
  end
  def update_frequency=(switch)
    self.settings[:update_frequency] = switch
  end

  def vmstate_refresh_frequency
    self.settings[:vmstate_refresh_frequency]
  end
  def vmstate_refresh_frequency=(switch)
    self.settings[:vmstate_refresh_frequency] = switch
  end

  def read_only
    self.settings[:readonly]
  end
  def read_only=(switch)
    self.settings[:readonly] = switch
  end

  def logLevel
    self.settings[:log][:level]
  end
  def logLevel=(switch)
    self.settings[:log][:level] = switch
  end

  def logWrapTime
    self.settings[:log][:wrap_time]
  end
  def logWrapTime=(switch)
    self.settings[:log][:wrap_time] = switch
  end

  def logWrapSize
    self.settings[:log][:wrap_size]
  end
  def logWrapSize=(switch)
    self.settings[:log][:wrap_size] = switch
  end

  def wsListenPort
    self.settings[:wsListenPort]
  end
  def wsListenPort=(switch)
    self.settings[:wsListenPort] = switch
  end

  def forceVmScan
    self.settings[:forceFleeceDefault]
  end
  def forceVmScan=(switch)
    self.settings[:forceFleeceDefault] = switch
  end

  def eventing_enabled
    enabled = self.settings.fetch_path(:eventing, :enabled)
    # If enabled flag is nil that means it has not been initialied.
    # Determine proper default state by check what hypervisor type
    if enabled.nil?
      if ['KVM'].include?(self.host.vmm_vendor)
        enabled = self.eventing_enabled = true
        self.save
      end
      enabled = false if enabled.nil?
    end
    return enabled
  end

  def eventing_enabled=(switch)
    self.settings[:eventing] = {} if self.settings[:eventing].nil?
    self.settings[:eventing][:enabled] = switch
  end

  def eventing_frequency
    freq = self.settings.fetch_path(:eventing, :frequency)
    return 60 if freq.nil?
    return freq
  end

  def eventing_frequency=(switch)
    self.settings[:eventing] = {} if self.settings[:eventing].nil?
    self.settings[:eventing][:frequency] = switch
  end
  # settings hash methods

  # This is called from the UI
  def update_activate_agent_version(update)
    raise MiqException::MiqDeploymentError, "There is another #{MIQHOST_PRODUCT_NAME} deployment already in progress" if self.is_update_active?
    task = MiqTask.create(:name => "SmartProxy Activate Agent")
    MiqQueue.put(:instance_id => self.id, :class_name => self.class.to_s, :method_name => "update_activate_agent_version_from_queue", :args => [update.id, task.id], :zone => self.host.my_zone)
  end

  # This is called from the queue
  def update_activate_agent_version_from_queue(product_update_id, taskid=nil)
    task = MiqTask.find_by_id(taskid)  unless taskid.nil?
    task.update_status("Active", "Ok", "Starting SmartProxy Update") if task
    update = ProductUpdate.find(product_update_id)
    update_agent_version(update, taskid)
    activate_agent_version(update, taskid)
  end

  def update_agent_version(update, taskid=nil)
    task = MiqTask.find_by_id(taskid)  unless taskid.nil?
    url, meta = self.get_version_metadata(update, taskid)
    task.update_status("Active", "Ok", "Initiating SmartProxy download of version #{meta[:version]}") if task
    call_ws(OpenStruct.new("method_name"=>"GetAgent", "url"=>url, "metadata"=>meta.inspect, "taskid"=>taskid))
  end

  def activate_agent_version(update, taskid=nil)
    task = MiqTask.find_by_id(taskid)  unless taskid.nil?
    url, meta = self.get_version_metadata(update, taskid)
    self.update_attribute(:upgrade_settings, {:taskid=>taskid, :build=>meta[:build], :version => meta[:version]})
    task.update_status("Active", "Ok", "Sending request to activate SmartProxy version #{meta[:version]}") if task
    call_ws(OpenStruct.new("method_name"=>"ActivateAgent", "url"=>url, "metadata"=>meta.inspect, "taskid"=>taskid))
    task.update_status("Active", "Ok", "Sent request to activate SmartProxy version #{meta[:version]}") if task
  end

  def get_version_metadata(update, taskid=nil)
    file = get_agent_file(update)

    meta = {
      :name => File.basename(file),
      :size => File.size(file),
      :mtime => File.mtime(file).to_f,
      :build => update.build,
      :version => "#{update.version}.#{update.build}",
      :md5 => update.md5,
      :taskid => taskid
    }

    # Example: http://localhost:3000/agent/get?id=1&product_update_id=2171&task_id=5
    url = "/agent/get?id=#{self.id}&product_update_id=#{update.id}&task_id=#{taskid}"

    return url, meta
  end

  def deploy_agent_version_from_job(options, &block)
    case self.host.platform
    when "linux" then   self.deploy_agent_to_linux(options, &block)
    when "windows" then self.deploy_agent_to_windows(options)
    else
      raise MiqException::MiqDeploymentError, "No install method available for host [#{self.host.id}-#{self.host.name}] Platform:[#{self.host.platform}]"
    end
  end

  def deploy_agent_to_linux(options, &block)
    #
    # TODO: Open ssh port via vmware web-service.
    #
    update = ProductUpdate.find(options[:update])
    $log.info "deploy_agent_to_linux: Starting deployment of agent to Host [#{self.host.id}-#{self.host.name}] with Product Update ID:[#{update.id}] Name:[#{update.name}] Build:[#{update.build}] Platform:[#{update.platform}] Architecture:[#{update.arch}] Size:[#{update.binary_blob.size}]"

    self.host.connect_ssh do |ssu|
      #
      # Check for existing miqhost install
      #
      $log.info "deploy_agent_to_linux: Checking for existing install"
      miqhost_running = false
      host_cfg = {}
      yield("Checking for existing install") if block_given?
      begin
        miqhost_status = ssu.exec("ls /etc/init.d/miqhostd")
        yield("Checking existing install status") if block_given?
        miqhost_status = ssu.shell_exec("/etc/init.d/miqhostd status")
        miqhost_running = miqhost_status.include?("is running")
        yield("Checking existing install configuration") if block_given?
        miqhost_config = ssu.exec("cat /opt/miq/miqhost.yaml")
        host_cfg = YAML.load(miqhost_config)
      rescue => err
      end

      if miqhost_running
        if host_cfg[:vmdbHost]
          raise MiqException::MiqDeploymentError, "SmaryProxy is being managed by EVM Server at address [#{host_cfg[:vmdbHost]}]"
        else
          raise MiqException::MiqDeploymentError, "SmaryProxy is being managed by another EVM Server"
        end
      end

      #
      # Check to see if we have enough disk space on the host to deploy the agent.
      #
      $log.info "deploy_agent_to_linux: Performing disk space check"
      yield("Performing disk space check") if block_given?
      dsh = Hash.new
      begin
        ssu.exec("df -k -l | tail +2").each_line do |l|
          la = l.split(/\s+/)
          dsh[la[5]] = la[3]
        end
      rescue => err
        $log.log_backtrace(err)
      end

      if !(avail = dsh['/var/tmp'] || dsh['/var'] || dsh['/'])
        $log.info "deploy_agent_to_linux: Could not determine available disk space on host"
      else
        raise MiqException::MiqDeploymentError, "Not enough disk space to install smarthost: #{avail.to_f/1024.0} MB available, #{MIN_LINUX_MB} MB required" if avail.to_i < MIN_LINUX_MB * 1024
      end

      #
      # Copy the agent to a temp file on the target machine.
      #
      yield("Copying install media to remote system.") if block_given?
      $log.info "deploy_agent_to_linux: Copying install media from db.  Product Update ID:[#{update.id}] Name:[#{update.name}] Build:[#{update.build}] Platform:[#{update.platform}] Architecture:[#{update.arch}] Size:[#{update.binary_blob.size}]"
      file = get_agent_file(update)
      dfile = File.join("/var/tmp", File.basename(file).split("_")[0])
      $log.info "deploy_agent_to_linux: Copying #{file} to #{dfile} on #{ssu.host}"
      ssu.cp(file, dfile)
      $log.info "deploy_agent_to_linux: #{dfile} on #{ssu.host} copy complete"

      #
      # Make sure we can execute the file.
      #
      ssu.exec("chmod 700 #{dfile}")
      $log.info ssu.exec("ls -l #{dfile}")

      #
      # Install the agent on the target host.
      #
      yield("Running remote install.") if block_given?
      zone = Zone.find_by_name(self.my_zone)
      vmdbHost = zone.settings[:proxy_server_ip] unless zone.settings.blank? || zone.settings[:proxy_server_ip].blank?
      vmdbHost ||= VMDB::Config.new("vmdb").config[:server][:host]
      vmdbHost ||= MiqSockUtil.getIpAddr
      vmdbPort = VMDB::Config.new("vmdb").config.fetch_path(:server, :listening_port) || 80
      $log.info "deploy_agent_to_linux: Installing on #{ssu.host}, Server Host: [#{vmdbHost}], Server Port: [#{vmdbPort}]..."
      ssu.shell_exec("#{dfile} -h #{vmdbHost} -p #{vmdbPort} install", "Installation complete.")
      $log.info "deploy_agent_to_linux: Install on #{ssu.host} complete."

      #
      # Remove the temp file.
      #
      yield("Performing install cleanup") if block_given?
      ssu.exec("rm -f #{dfile}")

      #
      # Start the agent.
      #
      yield("Starting remote #{MIQHOST_PRODUCT_NAME}") if block_given?
      $log.info "deploy_agent_to_linux: starting agent..."
      ssu.shell_exec("/etc/init.d/miqhostd start", "Done")
      $log.info "deploy_agent_to_linux: agent started"
    end
  end

  def deploy_agent_to_windows(options)
    update = options[:update]
    build = update.build

    # Find the proxy host to which we will send the command to replicate itself.
    # Using the default repository scanning host as the proxy host.
    $log.debug "deploy_agent_to_windows: Finding proxy host..."
    proxyHost = nil
    proxyHostId = VMDB::Config.new("vmdb").config[:repository_scanning][:defaultsmartproxy]
    proxyHost = MiqProxy.find(proxyHostId) unless proxyHostId.nil?
    raise MiqException::MiqDeploymentError, "No Host is configured for deployment, contact your EVM Administrator" if proxyHost.nil?
    $log.debug "deploy_agent_to_windows: Find of proxy host complete."

    # Send down the desired host level to the proxy host.
    # The host will handle if it already has the desired file cached.
    proxyHost.update_agent_version(update)

    # Send the webservice call to the proxy host, telling it to replicate itself to this host.
    address = self.host.address
    $log.debug "deploy_agent_to_windows: Installing on #{address}..."

    # Required Free space 300 MB
    requireFreeSpace = 1.megabyte * 300
    proxyHost.call_ws(OpenStruct.new("method_name"=>"ReplicateHost",
        "args"=>[{:hostname=>self.host.hostname,
            :ip=>address,
            :username=>self.host.authentication_userid,
            :password=>self.host.authentication_password_encrypted,
            :version=>build,
            :requiredFreeSpace=>requireFreeSpace}.inspect]))
    $log.debug "deploy_agent_to_windows: Install on #{address} complete."
  end

  def get_agent_file(product_update)
    file = product_update.file_from_db(self)
    raise MiqException::MiqDeploymentError, "no media found for version \"#{product_update.build}\"" unless File.exists?(file)
    return file
  end

  def deploy_proxy_version(userid, update, deploy_options={})
    raise MiqException::MiqDeploymentError, "Invalid update type [#{update.class}]" unless update.is_a?(ProductUpdate)
    raise MiqException::MiqDeploymentError, "There is another #{MIQHOST_PRODUCT_NAME} deployment already in progress" if self.is_update_active?
    deploy_options.reverse_merge!(:update => update.id)

    requ_plat = update.platform.to_s.downcase
    host_plat = self.host.platform.to_s.downcase

    raise MiqException::MiqDeploymentError, "Deploy #{MIQHOST_PRODUCT_NAME} Cannot deploy update: [#{update.name if update.name}], id: [#{update.id}] which requires platform: [#{requ_plat}] to [#{host_plat}]" unless requ_plat == host_plat
    raise MiqException::MiqDeploymentError, "#{MIQHOST_PRODUCT_NAME} deployment requires a valid user id and password" if self.host.authentication_invalid? && deploy_options[:userid].blank?

    options = {
      :target_id => self.host.id,
      :target_class => self.host.class.base_class.name,
      :name => "Deploy #{MIQHOST_PRODUCT_NAME} to host #{self.host.name}",
      :userid => userid,
      :deploy_options => deploy_options,
      :agent_class => self.class.base_class.name,
      :agent_id => self.id
    }

    job = Job.create_job("HostRemoteDeploy", options)
    timeout = (VMDB::Config.new("vmdb").config.fetch_path(:smartproxy_deploy, :queue_timeout) || 30.minutes).to_i_with_method
    MiqQueue.put(:class_name=>"Job", :method_name=>"signal", :instance_id=>job.id, :args=>[:start], :zone => self.host.my_zone, :role => "smartstate", :msg_timeout => timeout)
  end

  alias :deploy_agent_version :deploy_proxy_version

  def is_update_active?
    info = active_update_info
    return false if info.nil?
    $log.info "#{self.class.name}.is_update_active?  Result:[#{true}]  Object:[#{info[:object].class}:#{info[:object].id}]"
    return true
  end

  def active_update_info
    unless self.upgrade_settings.nil?
      t = MiqTask.find_by_id(self.upgrade_settings[:taskid])
      unless t.nil? || t.state == 'Finished'
        # If the task is not finished make sure we had a recent update.  Otherwise
        # consider the process failed so another attempt to update can run.
        return self.upgrade_settings.merge(:type => :upgrade, :object => t) if Time.now - t.updated_on < 5.minutes
      end
    end

    jobs = Job.find(:all, :conditions=>["type = ? and agent_class = ? and agent_id = ? and state != 'finished'",'HostRemoteDeploy', self.class.name, self.id])
    job = jobs.detect {|j| Time.now - j.updated_on < 5.minutes}
    return {:type => :deploy, :object => job} unless job.nil?

    return nil
  end

  def powershell_command(ps_script, return_type='object')
    options = {"args"=>[ps_script, return_type], 'method_name'=>'powershell_command'}
    ost = OpenStruct.new(options)
    return self.class.process_powershell_object(self.call_ws(ost))
  end

  def powershell_command_async(ps_script, return_type='object', ps_options = {}, queue_parms = {})
    cmd_options = {:ps_options => ps_options, :queue_parms => queue_parms}
    options = YAML.dump(cmd_options).miqEncode
    self.call_ws(OpenStruct.new({"args"=>[ps_script, return_type, options], 'method_name'=>'powershell_command_async'}))
  end

  def self.process_powershell_object(result)
    require 'miq-powershell'
    result = YAML.load(result) if result.kind_of?(String)
    MiqPowerShell.log_messages(result[:ps_logging]) unless result[:ps_logging].nil?
    raise Object.const_get(result[:error_class]), result[:message] if result[:error] == true
    return result[:ps_object]
  end

  def is_active?
    self.state == "on"
  end

  def self.active_by_domain(domain_name, platform=nil)
    self.all(:include => :host).inject([]) do |proxies, p|
      if p.host && (platform.nil? || p.host.platform == platform)
        proxies << p if (p.host.domain.to_s.downcase == domain_name.downcase) && p.is_active?
      end
      proxies
    end
  end
end
