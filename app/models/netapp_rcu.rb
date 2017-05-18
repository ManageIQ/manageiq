require 'RcuWebService/RcuClientBase'

class NetappRcu < StorageManager
  has_many  :controllers,
            :class_name  => "StorageManager",
            :foreign_key => "parent_agent_id"

  DEFAULT_AGENT_TYPE = 'RCU'
  default_value_for :agent_type, DEFAULT_AGENT_TYPE

  def self.find_rcu_vcs
    zoneId = MiqServer.my_server.zone.id
    ra = []
    ManageIQ::Providers::Vmware::InfraManager.where(:zone_id => zoneId).each do |vc|
      begin
        # TODO: Use hostname, not ipaddress
        rcu = RcuClientBase.new(vc.ipaddress, *vc.auth_user_pwd(:default))
        rcu.getMoref("", "")
      rescue => err
        next
      end
      ra << vc
    end
    ra
  end

  def self.add_from_ems(ems)
    unless ems.kind_of?(ManageIQ::Providers::Vmware::InfraManager)
      raise _("NetappRcu.add_from_ems: unsupported ems type: %{type}") % {:type => ems.type}
    end
    # TODO: Use hostname, not ipaddress
    add(ems.ipaddress,
        ems.authentication_userid(:default),
        ems.authentication_password(:default),
        ems.zone_id, ems.hostname, ems.name)
  end

  def self.add_all_from_ems
    ra = []
    find_rcu_vcs.each { |vc| ra << add_from_ems(vc) }
    ra
  end

  def self.get_rcu_for_object(obj)
    return nil unless obj.respond_to?(:ext_management_system)
    return nil unless (ems = obj.ext_management_system)

    # TODO: Use hostname, not ipaddress
    find_by_ipaddress(ems.ipaddress)
  end

  def rcu_client
    # TODO: Use hostname, not ipaddress
    @rcuClient ||= RcuClientBase.new(ipaddress, authentication_userid, authentication_password)
  end

  def add_controller(ipaddress, username, password, hostname = nil, name = nil, rcuData = {})
    # TODO: Use hostname, not ipaddress
    c = NetappRemoteService.add(ipaddress, username, password, NetappRemoteService::DEFAULT_AGENT_TYPE, zone_id, hostname, name)
    controllers << c unless controllers.include?(c)

    cRcuData = c.get_ts_data(:rcu)

    cRcuData[:aggregates] ||= rcuData[:aggregates]
    cRcuData[:volumes] ||= rcuData[:volumes]
    cRcuData[:ssl] ||= rcuData[:ssl]

    unless cRcuData[:aggregates] && cRcuData[:volumes]
      # TODO: Use hostname, not ipaddress
      unless (oss = NetappRemoteService.find_controller_by_ip(ipaddress))
        _log.info "could not find controller #{ipaddress}"
      else
        cRcuData[:aggregates] ||= NetappRemoteService.aggregate_names(oss) || []
        cRcuData[:volumes] ||= NetappRemoteService.volume_names(oss) || []
      end
    end
    c.set_ts_data(:rcu, cRcuData)

    c
  end

  def get_controller_by_ipaddress(ip)
    # TODO: Use hostname, not ipaddress
    controllers.find_by_ipaddress(ip)
  end

  def get_controller_by_name(name)
    controllers.find_by(:name => name)
  end

  # TODO: Use hostname, not ipaddress
  def set_current_controller_by_ipaddress(ip)
    @currentController = controllers.find_by_ipaddress(ip)
    @currentControllerSpec = nil
    @currentController
  end

  def set_current_controller_by_name(name)
    @currentController = controllers.find_by(:name => name)
    @currentControllerSpec = nil
    @currentController
  end

  def current_controller
    raise _("NetappRcu.current_controller: current controller is not set") unless @currentController
    @currentController
  end

  def controller_name
    current_controller.name
  end

  def controller_spec
    @currentControllerSpec ||= RcuHash.new("ControllerSpec") do |cs|
      # TODO: Use hostname, not ipaddress
      cs.ipAddress = current_controller.ipaddress
      cs.username  = current_controller.authentication_userid
      cs.password  = current_controller.authentication_password
      cs.ssl       = controller_ssl
    end
  end

  def controller_ssl
    cRcuData = current_controller.get_ts_data(:rcu)
    (cRcuData[:ssl].nil? ? false : cRcuData[:ssl])
  end

  def controller_aggregates
    cRcuData = current_controller.get_ts_data(:rcu)
    cRcuData[:aggregates] || []
  end

  def controller_volumes
    cRcuData = current_controller.get_ts_data(:rcu)
    cRcuData[:volumes] || []
  end

  def controller_has_aggregate?(name)
    controller_aggregates.include?(name)
  end

  def controller_has_volume?(name)
    controller_volumes.include?(name)
  end

  def create_datastore(params)
    container         = params[:container]
    aggregate_or_volume_name  = params[:aggregate_or_volume_name]
    datastore_name        = params[:datastore_name]
    size            = params[:size]
    protocol          = params[:protocol] || "NFS"
    thin_provision        = (params[:thin_provision].nil? ? false : params[:thin_provision])
    auto_grow         = (params[:auto_grow].nil? ? false : params[:auto_grow])
    auto_grow_increment     = params[:auto_grow_increment]
    auto_grow_maximum     = params[:auto_grow_maximum]
    size            = params[:size]

    # Size must be at least 1 gigabyte
    size = 1.gigabyte if size < 1.gigabyte

    if protocol == "NFS"
      unless controller_has_aggregate?(aggregate_or_volume_name)
        raise _("Controller '%{name}' does not have aggregate '%{item}'") % {:name => controller_name,
                                                                             :item => aggregate_or_volume_name}
      end
    elsif protocol == "VMFS" # XXX ???
      unless controller_has_volume?(aggregate_or_volume_name)
        raise _("Controller '%{name}' does not have volume '%{item}'") % {:name => controller_name,
                                                                          :item => aggregate_or_volume_name}
      end
    else
      raise _("Unrecognized protocol: %{protocol}") % {:protocol => protocol}
    end
    raise _("Container not provided") if container.nil?

    if auto_grow
      raise _("auto_grow it true, but auto_grow_increment is not set") unless auto_grow_increment
      raise _("auto_grow it true, but auto_grow_maximum is not set") unless auto_grow_maximum
    else
      auto_grow_increment = 0
      auto_grow_maximum = 0
    end

    # Figure out the target's Managed Object Reference
    targetMor = rcu_client.vimMorToRcu(container.ems_ref_obj)

    # Create the parameters needed for the rcu.createDatastore methods
    datastoreSpec = RcuHash.new("DatastoreSpec") do |ds|
      # RCU
      # ds.aggrOrVolName = aggregate_or_volume_name
      # VSC
      ds.containerName  = aggregate_or_volume_name
      ds.controller   = controller_spec
      ds.datastoreNames = datastore_name
      ds.numDatastores  = 1
      ds.protocol     = (protocol == 'VMFS') ? 'ISCSI' : protocol # XXX ???
      ds.sizeInMB     = size.to_i / 1.megabyte
      ds.targetMor    = targetMor
      ds.thinProvision  = thin_provision
      ds.volAutoGrow    = auto_grow
      ds.volAutoGrowInc = auto_grow_increment.to_i / 1.megabyte
      ds.volAutoGrowMax = auto_grow_maximum.to_i / 1.megabyte
    end

    _log.info("Creating #{protocol} containerName=<#{aggregate_or_volume_name}> with size=<#{size}> as datastore=<#{datastore_name}> on NetApp Controller=<#{controller_name}>")
    _log.info("rcu.createDatastore parameters: ds.containerName=<#{datastoreSpec.aggrOrVolName}>, ds.datastoreNames=<#{datastoreSpec.datastoreNames}>, ds.numDatastores=<#{datastoreSpec.numDatastores}>, ds.protocol=<#{datastoreSpec.protocol}>, ds.sizeInMB=<#{datastoreSpec.sizeInMB}>, ds.targetMor=<#{datastoreSpec.targetMor}>, ds.thinProvision=<#{datastoreSpec.thinProvision}>, ds.volAutoGrow=<#{datastoreSpec.volAutoGrow}>, ds.volAutoGrowInc=<#{datastoreSpec.volAutoGrowInc}>, ds.volAutoGrowMax=<#{datastoreSpec.volAutoGrowMax}>")
    rv = rcu_client.createDatastore(datastoreSpec)
    _log.info("Return Value=<#{rv}> of class=<#{rv.class.name}>")
    return rv
  rescue Handsoap::Fault => hserr
    _log.error "Handsoap::Fault { :code => '#{hserr.code}', :reason => '#{hserr.reason}', :details => '#{hserr.details.inspect}' }"
    $log.error hserr.backtrace.join("\n")
    raise
  rescue => err
    _log.error err.to_s
    $log.error err.backtrace.join("\n")
    raise
  end
end
