module MiqProvisionVmwareViaNetAppRcu::Cloning

  def find_destination_in_vmdb
    VmOrTemplate.find_by_name(dest_name)
  end

  def require_net_app_rcu
    @require_net_app_rcu ||= begin
      $:.push("#{Rails.root}/../lib/RcuWebService")
      require 'RcuClientBase'
      true
    end
  end

  def prepare_for_clone
    require_net_app_rcu

    ems = self.source.ext_management_system
    rcu = RcuClientBase.new(ems.ipaddress, *ems.auth_user_pwd)

    netapp_filer = dest_datastore.netapp_filer
    controller = RcuHash.new("ControllerSpec") do |cs|
      cs.ipAddress = netapp_filer.ipaddress
      cs.password  = netapp_filer.password
      cs.ssl       = false
      cs.username  = netapp_filer.userid
    end

    srcVmtMor = rcu.getMoref(self.source.name, "VirtualMachine")
    raise MiqException::MiqProvisionError, "Source VM: #{self.source.name} not found" unless srcVmtMor

    dest_host_mor = rcu.getMoref(dest_host.name, "HostSystem")
    raise MiqException::MiqProvisionError, "Target host: #{dest_host.name} not found" unless dest_host_mor

    dest_datastore_mor = rcu.getMoref(dest_datastore.name, "Datastore")
    raise MiqException::MiqProvisionError, "Target datastore: #{dest_datastore.name} not found" unless dest_datastore_mor

    vmFiles = rcu.getVmFiles(srcVmtMor)
    files = RcuArray.new()

    vmFiles.each do |f|
      files << RcuHash.new("Files") do |nf|
        nf.destDatastoreSpec = RcuHash.new("DestDatastoreSpec") do |dds|
          dds.controller    = controller
          dds.mor           = dest_datastore_mor
          dds.numDatastores = 0
          dds.thinProvision = false
          dds.volAutoGrow   = false
        end
        nf.sourcePath = f.sourcePath
      end
    end

    clones = RcuHash.new("Clones") do |cl|
      cl.entry = RcuArray.new() do |ea|
        ea << RcuHash.new("Entry") do |e|
          e.key   = dest_name
          e.value = ""
        end
      end
    end

    cloneSpec = RcuHash.new("CloneSpec") do |cs|
      cs.clones         = clones
      cs.containerMoref = dest_host_mor
      cs.files          = files
      cs.templateMoref  = srcVmtMor
    end

    cloneSpec
  end

  def log_clone_options(options)
    log_header = "MIQ(#{self.class.name}#log_clone_options)"

    $log.info("#{log_header} Provisioning [#{self.source.name}] to [#{dest_name}]")
    $log.info("#{log_header} Source Template:            [#{self.source.name}]")
    $log.info("#{log_header} Destination VM Name:        [#{dest_name}]")
    $log.info("#{log_header} Destination Host:           [#{dest_host.name} (#{dest_host.ems_ref})]")
    $log.info("#{log_header} Destination Datastore:      [#{dest_datastore.name} (#{dest_datastore.ems_ref})]")
  end

  def start_clone(clone_spec)
    require_net_app_rcu

    ems = self.source.ext_management_system
    rcu = RcuClientBase.new(ems.ipaddress, *ems.auth_user_pwd)

    rv = rcu.createClones(clone_spec)
    rcu.rcuMorToVim(rv)
  end

end
