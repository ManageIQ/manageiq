require 'miq_storage_defs'
require 'cim_association_defs'
require 'lun_durable_names'

class VmdbStorageBridge

  include MiqStorageDefs

  MIQ_CimHostSystem_TO_MIQ_CimDatastore   = CimAssociations.MIQ_CimHostSystem_TO_MIQ_CimDatastore
  MIQ_CimVirtualMachine_TO_MIQ_CimHostSystem  = CimAssociations.MIQ_CimVirtualMachine_TO_MIQ_CimHostSystem
  MIQ_CimVirtualMachine_TO_MIQ_CimVirtualDisk = CimAssociations.MIQ_CimVirtualMachine_TO_MIQ_CimVirtualDisk
  MIQ_CimVirtualDisk_TO_MIQ_CimDatastore    = CimAssociations.MIQ_CimVirtualDisk_TO_MIQ_CimDatastore
  MIQ_CimDatastore_TO_CIM_FileShare     = CimAssociations.MIQ_CimDatastore_TO_CIM_FileShare
  MIQ_CimDatastore_TO_CIM_StorageVolume   = CimAssociations.MIQ_CimDatastore_TO_CIM_StorageVolume

  def initialize
    @zone = MiqServer.my_server.zone.id
    @agent  = CimVmdbAgent.find(:all, :conditions => { :agent_type => 'VMDB', :zone_id => @zone }).first
    @agent  = CimVmdbAgent.add(nil, nil, nil, 'VMDB', @zone, "VMDB-#{@zone}") unless @agent
  end

  def collectData
    idToDsNode    = {}
    idToHostNode  = {}

    vim       = nil
    last_conn_error = nil

    $log.info "VmdbStorageBridge.collectData entered"

    EmsVmware.where(:zone_id => @zone).find_each do |ems|
      $log.info "VmdbStorageBridge.collectData: found EmsVmware #{ems.hostname}"
      begin
        begin
          vim = ems.connect
        rescue Exception => verr
          $log.error "VmdbStorageBridge.collectData: could not connect to ems - #{ems.ipaddress}"
          $log.error verr.to_s
          last_conn_error = verr
          next
        end

        ems.hosts.find_each do |host|
          $log.debug "VmdbStorageBridge.collectData: #{host.hostname}\t#{host.ipaddress}"
          hostNode = newNode(host, 'MIQ_CimHostSystem')
          idToHostNode[host.id] = hostNode

          #
          # Hash device UUIDs by canonical name.
          #
          cnToDurableNames = {}
          scsiLuns = vim.getMoProp(host.ems_ref_obj, "config.storageDevice.scsiLun").config.storageDevice.scsiLun
          scsiLuns.each { |sn| cnToDurableNames[sn.canonicalName] = LunDurableNames.new(sn.alternateName) }

          host.storages.find_each do |storage|
            $log.debug "VmdbStorageBridge.collectData:\t#{storage.name}\t#{storage.location}"

            unless idToDsNode[storage.id]
              next unless (ds = vim.dataStoresByMor[storage.ems_ref_obj])

              addProps    = {}
              durableNames  = nil

              if ds.info.xsiType == 'NasDatastoreInfo'
                nas = ds.info.nas
                url = "#{nas['type']}://#{nas.remoteHost}/#{nas.remotePath}/"
                addProps['url'] = url
              else  # VMFS
                durableNames = LunDurableNames.new
                #
                # VMFS datastores can be based on more than one extent,
                # so they can be associated with more than one storage volume.
                #
                # Save the durable names of each extent in the datastore instance,
                # so we can make the association between the datastore and its
                # storage volumes when we bridge associations.
                #
                ds.info.vmfs.extent.each do |ext|
                  next unless (dn = cnToDurableNames[ext.diskName])
                  durableNames << dn
                end
              end

              dsNode = newNode(storage, 'MIQ_CimDatastore', addProps, durableNames)
              idToDsNode[storage.id] = dsNode
            else
              dsNode = getNode('MIQ_CimDatastore', storage)
            end

            #
            # Add associations between the host and its datastores.
            #
            hostNode.addAssociation(dsNode, MIQ_CimHostSystem_TO_MIQ_CimDatastore)
          end
        end
      ensure
        if vim
          vim.disconnect
          vim = nil
        end
      end

      ems.vms.find_each do |vm|
        vmNode = newNode(vm, 'MIQ_CimVirtualMachine')

        if (hostNode = idToHostNode[vm.host_id])
          #
          # Add association between the VM and its host.
          #
          vmNode.addAssociation(hostNode, MIQ_CimVirtualMachine_TO_MIQ_CimHostSystem)
        else
          $log.info "VmdbStorageBridge.collectData:\t*** Host node not found for VM: #{vm.name}"
        end

        vm.hardware.hard_disks.find_each do |disk|
          # $log.debug "\t\t#{disk.filename}"
          # $log.debug "\t\t\t#{disk.storage.name}"
          diskNode = newNode(disk, 'MIQ_CimVirtualDisk')

          #
          # Add association between the disk and its VM.
          #
          vmNode.addAssociation(diskNode, MIQ_CimVirtualMachine_TO_MIQ_CimVirtualDisk)

          if (dsNode = idToDsNode[disk.storage_id])
            #
            # Add association between the disk and its datastore.
            #
            diskNode.addAssociation(dsNode, MIQ_CimVirtualDisk_TO_MIQ_CimDatastore)
          else
            $log.debug "VmdbStorageBridge.collectData: *** Datastore node not found for disk: #{disk.filename}"
          end
        end
      end
    end

    if last_conn_error
      last_conn_error.set_backtrace([])
      raise last_conn_error
    end
    return nil
  end

  def getNode(cimClassName, row)
    objName   = rowToObjName(row, cimClassName)
    objNameStr  = objName.to_s

    node = MiqCimInstance.find_by_obj_name_str(objNameStr)

    raise "Node not found: #{objNameStr}" if node.nil?
    return node
  end

  def newNode(row, cimClassName, additionalProperties={}, tsObj=nil)
    objName     = rowToObjName(row, cimClassName)
    objNameStr    = objName.to_s
    newCimInstance  = WBEM::CIMInstance.new(cimClassName, rowToHash(row).merge(additionalProperties))

    node = MiqCimInstance.find_by_obj_name_str(objNameStr)

    if node.nil?
      node = MiqCimInstance.new
      node.class_name       = cimClassName
      node.class_hier       = [ cimClassName ]
      node.obj_name       = objName
      node.obj_name_str     = objNameStr
      node.source         = "VMDB"
      node.agent          = @agent
      node.zone_id        = @zone
      t = node.typeFromClassHier
      node.type         = t if t
      node.obj          = newCimInstance
      node.last_update_status   = STORAGE_UPDATE_OK
      node.vmdb_obj       = row
      node.type_spec_obj      = tsObj unless tsObj.nil?
      node.save
    else
      full_save = false

      unless node.obj.properties == newCimInstance.properties
        node.obj = newCimInstance
        full_save = true
      end

      unless node.type_spec_obj == tsObj
        node.type_spec_obj = tsObj
        full_save = true
      end

      if full_save
        node.last_update_status = STORAGE_UPDATE_OK
        node.save
      else
        #
        # The node exists and its properties have not changed, so there
        # is no need to update the node.obj serialized column.
        # Calling update_all will update the status, but not the serialized cols.
        #
        MiqCimInstance.where(:id => node.id).update_all(:last_update_status => STORAGE_UPDATE_OK)
      end
      node.mark_associations_stale
    end

    return(node)
  end

  def rowToObjName(row, cimClassName)
    MiqObjName.new("#{row.class}:#{row.id}", cimClassName)
  end

  def bridgeAssociations
    #
    # Find all VIM datastore instances in this zone.
    #
    dsq = MiqCimInstance.where(:class_name => 'MIQ_CimDatastore', :zone_id => @zone)

    #
    # Get reference hash to CIM_FileShare objects.
    #
    fsHash = getFileshareRefs
    svHash = getStorageVolumeRefs

    dsq.find_each do |ds|
      store_type = ds.obj.properties['store_type'].value
      if store_type == 'NFS' || store_type == 'NAS'
        key = ds.obj.properties['url'].value
        next unless (backingId = fsHash[key])
        next unless (backingNode = SniaFileShare.find(backingId))
        #
        # Add the association between the datastore and the fileshare.
        #
        $log.info "VmdbStorageBridge.bridgeAssociations: Adding CIM_FileShare association: #{key}"
        ds.addAssociation(backingNode, MIQ_CimDatastore_TO_CIM_FileShare)
      else
        ds.durableNames.each do |dna|
          backingId = nil
          backingKey  = nil
          dna.each do |dn|
            backingKey = dn.data
            break if (backingId = svHash[backingKey])
          end
          next if backingId.nil?
          next unless (backingNode = CimStorageVolume.find(backingId))
          #
          # Add the association between the datastore and the storage volume.
          #
          $log.info "VmdbStorageBridge.bridgeAssociations: Adding CIM_StorageVolume association: #{backingKey}"
          ds.addAssociation(backingNode,  MIQ_CimDatastore_TO_CIM_StorageVolume)
        end
      end
    end
    return nil
  end

  def getFileshareRefs
    refs = {}

    CimComputerSystem.find_each do |ccs|
      ccsIds = []
      ipEndpoints = ccs.protocol_endpoints("CIM_IPProtocolEndpoint")
      ipEndpoints.each do |ipNode|
        next if (ip = ipNode.obj['IPv4Address']) == "127.0.0.1"
        next if ip.nil? || ip.empty?
        ccsIds << ip
        ai = Socket.getaddrinfo(ip, 0, Socket::AF_UNSPEC, Socket::SOCK_STREAM, nil, Socket::AI_CANONNAME)
        ccsIds << ai.first[2]
      end

      ccs.hosted_file_shares.each do |sh|
        ccsIds.each do |id|
          url = "NFS://#{id}/#{sh.obj['Name']}/"
          refs[url] = sh.id
        end
      end
    end
    return refs
  end

  def getStorageVolumeRefs
    svHash = {}

    CimStorageVolume.find_each do |sv|
      svHash[sv.correlatable_id] = sv.id
    end
    return svHash
  end

  def rowToHash(row)
    rv = {}
    row.class.column_names.each { |cn| rv[cn] = row[cn] if WBEM.valid_cimtype?(row[cn]) }
    return rv
  end

end

# mvs = MiqVimSmis.new
# mvs.collectData
# mvs.bridgeAssociations

