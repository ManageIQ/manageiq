require 'rubygems'
require 'wbem'
require 'NetappManageabilityAPI/NmaClient'
require 'miq_storage_defs'
require 'cim_association_defs'
require 'yaml'
require 'sync'

module MiqOntapClient

  NAME_SPACE    = "root/ontap"
  MAX_CHUNK   = 20
  BLOCK_SIZE    = 4192
  LFS_BLOCK_SIZE  = 4096
  LUN_BLOCK_SIZE  = 512

  TYPE_SPECIFIC_MODEL_CLASSES = [
    "ONTAP_ConcreteExtent",   # < MiqCimInstance
    "ONTAP_FileShare",      # < SniaFileShare
    "ONTAP_LogicalDisk",    # < CimLogicalDisk
    "ONTAP_FlexVolExtent",    # < CimStorageExtent
    "ONTAP_PlexExtent",     # < MiqCimInstance
    "ONTAP_RAIDGroupExtent",  # < MiqCimInstance
    "ONTAP_StorageVolume",    # < CimStorageVolume
    "ONTAP_StorageSystem"   # < CimComputerSystem
  ]

  CLASS_TO_PERF_OBJECT_NAMES  = {
    "ONTAP_ConcreteExtent"  => [ "aggregate" ],
    "ONTAP_DiskExtent"    => [ "disk" ],
    "ONTAP_StorageVolume" => [ "LUN" ],
    "ONTAP_StorageSystem" => [ "System" ],
    "ONTAP_LogicalDisk"   => [ "volume" ]
    # "ONTAP_FlexVolExtent" => [ "volume" ]
  }

  PERF_OBJECT_NAMES = CLASS_TO_PERF_OBJECT_NAMES.values.flatten.uniq

  OBJECT_NAME_TO_INST_KEY   = {
    "aggregate"   => lambda { |i| i.name },
    "disk"      => lambda { |i| i.disk_uid },
    "LUN"     => lambda { |i| "#{i.path}-#{i.serial_number}" },
    "processor"   => lambda { |i| nil },
    "System"    => lambda { |i| nil },
    "volume"    => lambda { |i| i.name }
  }

  OBJECT_NAME_TO_COUNTERS   = {
    "aggregate"   => OntapAggregateDerivedMetric.counterNames,
    "disk"      => OntapDiskDerivedMetric.counterNames,
    "LUN"     => OntapLunDerivedMetric.counterNames,
    "System"    => OntapSystemDerivedMetric.counterNames,
    "volume"    => OntapVolumeDerivedMetric.counterNames
  }

  HOSTED_SHARE_ASSOCIATION          = CimAssociations.CIM_ComputerSystem_TO_CIM_FileShare
  SYSTEM_TO_LOGICAL_DISK_ASSOCIATION      = CimAssociations.CIM_ComputerSystem_TO_CIM_LogicalDisk
  SYSTEM_TO_STORAGE_VOLUME_ASSOCIATION    = CimAssociations.CIM_ComputerSystem_TO_CIM_StorageVolume
  SYSTEM_TO_FLEX_VOL_ASSOCIATION        = CimAssociations.ONTAP_StorageSystem_TO_ONTAP_FlexVolExtent
  SYSTEM_TO_IP_PROTOCOL_ENDPOINT        = CimAssociations.CIM_ComputerSystem_TO_CIM_IPProtocolEndpoint
  LFS_TO_LOGICAL_DISK_ASSOCIATION       = CimAssociations.SNIA_LocalFileSystem_TO_CIM_StorageExtent
  FILE_SHARE_TO_LFS_ASSOCIATION       = CimAssociations.CIM_FileShare_TO_SNIA_LocalFileSystem
  COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION  = CimAssociations.CIM_StorageExtent_TO_CIM_StorageExtent_down
  ONTAP_FILE_SHARE_TO_FLEX_VOL_ASSOCIATION  = CimAssociations.ONTAP_FileShare_TO_ONTAP_FlexVolExtent

  class OntapClient
    attr_reader   :server, :conn, :version_string
    attr_accessor :max_chunk

    include MiqStorageDefs

    @@counterInfoLock = Sync.new
    @@counterInfo   = nil

    def initialize(server, username, password)
      @currentTopElement  = nil
      @max_chunk      = MAX_CHUNK

      @server   = server
      @username = username
      @password = password

      @conn = NmaClient.new { |c|
        c.server    = @server
        c.auth_style  = NmaClient::NA_STYLE_LOGIN_PASSWORD
        c.username    = @username
        c.password    = @password
      }
      @version_string = @conn.system_get_version.version
    end

    def agent
      @agent ||= NetappRemoteService.add(@server, @username, @password, NetappRemoteService::DEFAULT_AGENT_TYPE)
    end

    def updateOntap
      @topMeNode, prior_status = storageSystem

      @diskInfoHash = hashDiskInfo

      logicalDiskNodeHash   = {}
      localFileSystemNodeHash = {}
      flexVolExtentNodeHash = {}

      volumeInfoHash = hashVolumeInfo
      volumeInfoHash.values.uniq.each do |vi|
        ldNode = logicalDiskNode(vi)
        logicalDiskNodeHash[vi.name] = ldNode
        @topMeNode.addAssociation(ldNode, SYSTEM_TO_LOGICAL_DISK_ASSOCIATION)

        lfsNode = localFileSystemNode(vi)
        localFileSystemNodeHash[vi.name] = lfsNode
        lfsNode.addAssociation(ldNode, LFS_TO_LOGICAL_DISK_ASSOCIATION)

        fveNode = flexVolExtentNode(vi)
        flexVolExtentNodeHash[vi.name] = fveNode
        ldNode.addAssociation(fveNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)

        @topMeNode.addAssociation(fveNode, SYSTEM_TO_FLEX_VOL_ASSOCIATION)
      end

      lunInfo.each do |li|
        svNode = storageVolumeNode(li)
        @topMeNode.addAssociation(svNode, SYSTEM_TO_STORAGE_VOLUME_ASSOCIATION)

        if (fveNode = flexVolExtentNodeHash[volNameFromPath(li.path)])
          svNode.addAssociation(fveNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)
        end
      end

      aggrInfo.each do |ai|
        ceNode = concreteExtentNode(ai)
        ai.volumes.contained_volume_info.to_ary.each do |cvi|
          if (fveNode = flexVolExtentNodeHash[cvi.name])
            fveNode.addAssociation(ceNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)
          end
        end
      end

      fileShareNodeHash = {}

      nfsExportHash = hashNfsExportRules
      nfsExportHash.each do |k, v|
        node = nfsFileShareNode(v)
        fileShareNodeHash["nfs:#{k}"] = node
        @topMeNode.addAssociation(node, HOSTED_SHARE_ASSOCIATION)

        if (lfsNode = localFileSystemNodeHash[volNameFromPath(k)])
          node.addAssociation(lfsNode, FILE_SHARE_TO_LFS_ASSOCIATION)
        end
        if (fveNode = flexVolExtentNodeHash[volNameFromPath(k)])
          node.addAssociation(fveNode, ONTAP_FILE_SHARE_TO_FLEX_VOL_ASSOCIATION)
        end
      end
      cifsShareHash = hashCifsShares
      cifsShareHash.each do |k, v|
        node = cifsFileShareNode(v)
        fileShareNodeHash["cifs:#{k}"] = node
        @topMeNode.addAssociation(node, HOSTED_SHARE_ASSOCIATION)

        if (lfsNode = localFileSystemNodeHash[volNameFromPath(k)])
          node.addAssociation(lfsNode, FILE_SHARE_TO_LFS_ASSOCIATION)
        end
        if (fveNode = flexVolExtentNodeHash[volNameFromPath(k)])
          node.addAssociation(fveNode, ONTAP_FILE_SHARE_TO_FLEX_VOL_ASSOCIATION)
        end
      end
    end

    def storageSystem
      cimClassName = "ONTAP_StorageSystem"
      ontap_info = @conn.system_get_info.system_info

      ipa = []
      ip_info = getIpInfo
      ip_info.each do |ai|
        next unless ai.v4_primary_address
        ipa << ai.v4_primary_address
      end

      keybindings = {
        "CreationClassName" => cimClassName,
        "Name"        => "ONTAP:#{ontap_info.system_id}"
      }
      additionalProperties = {
        "ElementName"     => ontap_info.system_name,
        "OtherIdentifyingInfo"  => ipa
      }

      obj = WBEM::CIMInstance.new(cimClassName, ontap_info.merge(keybindings).merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      ssNode, ignore = newNode(obj, objName, ontap_info, true)

      ip_info.each do |ai|
        ipNode = ipProtocolEndpointNode(ai, ssNode)
        ssNode.addAssociation(ipNode, SYSTEM_TO_IP_PROTOCOL_ENDPOINT)
      end

      return ssNode
    end

    IpAdEntAddr   = ".1.3.6.1.2.1.4.20.1.1"
    IpAdEntIfIndex  = ".1.3.6.1.2.1.4.20.1.2"
    IpAdEntNetMask  = ".1.3.6.1.2.1.4.20.1.3"
    IfDescr     = ".1.3.6.1.2.1.2.2.1.2"

    def getIpInfo
      ra = []
      oid = IpAdEntAddr
      loop do
        rv = @conn.snmp_get_next { nma_object_id oid }
        oid = rv.next_object_id
        break if oid[IpAdEntAddr].nil?

        ip    = rv.value
        netMask = @conn.snmp_get { nma_object_id "#{IpAdEntNetMask}.#{ip}"  }.value
        ifIdx = @conn.snmp_get { nma_object_id "#{IpAdEntIfIndex}.#{ip}"  }.value
        ifName  = @conn.snmp_get { nma_object_id "#{IfDescr}.#{ifIdx}"    }.value

        ra << NmaHash.new {
          v4_primary_address  ip
          v6_primary_address  nil
          subnet_mask     netMask
        }
      end
      return ra
    end

    def ipProtocolEndpointNode(ipInfo, ssNode)
      cimClassName = "ONTAP_IPProtocolEndPoint"

      ip4 = ipInfo.v4_primary_address
      snm = ipInfo.subnet_mask
      ip6 = ipInfo.v6_primary_address

      keybindings = {
        "CreationClassName"     => cimClassName,
        "Name"            => "IP:#{ipInfo.interface_name}:#{ip4}",
        "SystemCreationClassName" => ssNode.class_name,
        "SystemName"        => ssNode.property('Name')
      }

      additionalProperties = {
        "IPv4Address" => ip4,
        "SubnetMask"  => snm,
        "IPv6Address" => ip6,
        "NameFormat"  => "IP:<Interface>:<IPV4|6 Address>",
        "Caption"   => cimClassName,
        "Description" => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, lunInfo, false)

      return node
    end

    def storageVolumeNode(lunInfo)
      cimClassName = "ONTAP_StorageVolume"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => "#{lunInfo.path}:#{lunInfo.serial_number}",
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "ElementName"       => lunInfo.path,
        "Name"            => "NETAPP LUN #{lunInfo.serial_number}",
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "Caption"         => cimClassName,
        "Primordial"        => 'false',
        "ConsumableBlocks"      => (lunInfo.size.to_i/LUN_BLOCK_SIZE).to_s,
        "NumberOfBlocks"      => (lunInfo.size.to_i/LUN_BLOCK_SIZE).to_s,
        "DeltaReservation"      => "???",
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, lunInfo, false)

      return node
    end

    def logicalDiskNode(volInfo)
      cimClassName = "ONTAP_LogicalDisk"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => volInfo.uuid,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "ElementName"       => volInfo.name,
        "Name"            => volInfo.name,
        "DeltaReservation"      => volInfo.snapshot_percent_reserved.to_s,
        "BlockSize"         => BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => (volInfo.size_total.to_i/BLOCK_SIZE).to_s,
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => (volInfo.size_total.to_i/BLOCK_SIZE).to_s,
        "Primordial"        => 'false',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, volInfo, false)

      return node
    end

    def flexVolExtentNode(volInfo)
      cimClassName = "ONTAP_FlexVolExtent"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => volInfo.uuid,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "ElementName"       => volInfo.name,
        "Name"            => volInfo.name,
        "DeltaReservation"      => volInfo.snapshot_percent_reserved.to_s,
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => (volInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s,
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => (volInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s,
        "Primordial"        => 'false',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, volInfo, false)

      return node
    end

    def concreteExtentNode(aggrInfo)
      cimClassName = "ONTAP_ConcreteExtent"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => aggrInfo.uuid,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "Name"            => aggrInfo.name,
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Primordial"        => 'false',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, aggrInfo, false)

      aggrInfo.plexes.plex_info.to_ary.each do |pi|
        peNode = plexExtentNode(pi, aggrInfo)
        node.addAssociation(peNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)
      end

      return node
    end

    def plexExtentNode(plexInfo, aggrInfo)
      cimClassName = "ONTAP_PlexExtent"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => plexInfo.name,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "Name"            => plexInfo.name,
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Primordial"        => 'false',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, plexInfo, false)

      plexInfo.raid_groups.raid_group_info.to_ary.each do |ri|
        rgeNode = raidGroupExtentNode(ri, aggrInfo)
        node.addAssociation(rgeNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)
      end

      return node
    end

    def raidGroupExtentNode(rgInfo, aggrInfo)
      cimClassName = "ONTAP_RAIDGroupExtent"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => rgInfo.name,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "Name"            => rgInfo.name,
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => (aggrInfo.size_total.to_i/LUN_BLOCK_SIZE).to_s, # XXX
        "Primordial"        => 'false',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, rgInfo, false)

      rgInfo.disks.disk_info.to_ary.each do |di|
        if (diskInfo = @diskInfoHash[di.name])
          diskNode = diskNode(diskInfo)
          node.addAssociation(diskNode, COMPOSIT_EXTENT_TO_COMPONENT_ASSOCIATION)
        end
      end

      return node
    end

    def diskNode(diskInfo)
      cimClassName = "ONTAP_DiskExtent"

      keybindings = {
        "CreationClassName"     => cimClassName,
        "DeviceID"          => diskInfo.name,
        "SystemCreationClassName" => @topMeNode.class_name,
        "SystemName"        => @topMeNode.property('Name')
      }
      additionalProperties = {
        "Name"            => diskInfo.name,
        "BlockSize"         => LUN_BLOCK_SIZE.to_s, # XXX
        "ConsumableBlocks"      => diskInfo.physical_blocks,
        "Caption"         => cimClassName,
        "NumberOfBlocks"      => diskInfo.physical_blocks,
        "Primordial"        => 'true',
        "Description"       => cimClassName
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, diskInfo, false)

      return node
    end

    def localFileSystemNode(volInfo)
      cimClassName = "ONTAP_LocalFS"

      keybindings = {
        "CreationClassName"   => cimClassName,
        "CSCreationClassName" => @topMeNode.class_name,
        "CSName"        => @topMeNode.property('Name'),
        "Name"          => volInfo.uuid
      }
      additionalProperties = {
        "FileSystemSize"    => volInfo.size_total,
        "Caption"       => volInfo.name,
        "BlockSize"       => LFS_BLOCK_SIZE.to_s, # XXX
        "Root"          => "/vol/#{volInfo.name}",
        "FileSystemType"    => "WAFL"
      }

      obj = WBEM::CIMInstance.new(cimClassName, keybindings.merge(additionalProperties))
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, volInfo, false)

      return node
    end

    def nfsFileShareNode(nfsInfo)
      cimClassName = "ONTAP_FileShare"

      pn = nfsInfo.pathname
      props = {
        "ElementName" => pn,
        "Name"      => pn,
        "Caption"   => pn,
        "InstanceID"  => "#{@topMeNode.property('Name')}:nfs:#{pn}:(#{pn})"
      }
      keybindings = {
        "InstanceID"  => props["InstanceID"]
      }
      obj = WBEM::CIMInstance.new(cimClassName, props)
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, nfsInfo, false)

      return node
    end

    def cifsFileShareNode(cifsInfo)
      cimClassName = "ONTAP_FileShare"

      mp = cifsInfo.mount_point
      sn = cifsInfo.share_name
      props = {
        "ElementName" => sn,
        "Name"      => mp,
        "Caption"   => sn,
        "InstanceID"  => "#{@topMeNode.property('Name')}:cifs:#{mp}:(#{sn})"
      }
      keybindings = {
        "InstanceID"  => props["InstanceID"]
      }
      obj = WBEM::CIMInstance.new(cimClassName, props)
      objName = WBEM::CIMInstanceName.new(cimClassName, keybindings, nil, NAME_SPACE)

      node, ignore = newNode(obj, objName, cifsInfo, false)

      return node
    end

    def newNode(obj, objName, typeSpecObj, topMe=false)
      objNameStr = objName.to_s

      node = MiqCimInstance.find_by_obj_name_str(objNameStr)

      #
      # This is the first time we've encountered this node. Add it to the database.
      #
      if node.nil?
        node = MiqCimInstance.new
        @topMeNode = node if topMe
        className         = obj.classname.to_s
        node.class_name       = className
        node.class_hier       = classHier(className)
        node.namespace        = objName.namespace
        node.obj_name       = objName
        node.obj_name_str     = objNameStr
        node.obj          = obj
        node.type_spec_obj      = typeSpecObj
        node.source         = agent.agent_type
        node.is_top_managed_element = topMe
        node.top_managed_element  = @topMeNode unless topMe
        node.agent          = agent
        node.zone_id        = agent.zone_id
        node.last_update_status   = STORAGE_UPDATE_OK
        node.type         = typeForNode(node)
        agent.top_managed_elements << node if topMe
        @topMeNode.elements_with_metrics << node if CLASS_TO_PERF_OBJECT_NAMES[className]
        node.save

        return node, STORAGE_UPDATE_NEW
      end

      #
      # This node has already been updated through another agent
      # (or this agent through different storage device).
      #
      # XXX NOTE: if node.last_update_status == STORAGE_UPDATE_OK
      #   We may need to check if node.top_managed_element != @currentTopElement.
      #   This would indicate that more than one storage system is claiming ownership
      #   of the node. This may be the case for clusters.
      #
      return node, STORAGE_UPDATE_OK if node.last_update_status == STORAGE_UPDATE_OK

      prior_status = node.last_update_status
      node.obj        = obj
      node.type_spec_obj    = typeSpecObj
      node.agent        = agent
      node.zone_id      = agent.zone_id
      # add node to agent's top_managed_elements list
      node.agent_top_id   = agent.id if topMe
      node.last_update_status = STORAGE_UPDATE_OK
      node.save

      node.mark_associations_stale

      return node, prior_status
    end

    def typeForNode(node)
      # If the node has a type-specific model, return the model's class name.
      return node.typeFromClassName(node.class_name) if TYPE_SPECIFIC_MODEL_CLASSES.include?(node.class_name)
      # Otherwise, return the name if the general class that applies to this node.
      return node.typeFromClassHier
    end

    def classHier(className)
      CIM_CLASS_HIER[className] || (raise "OntapClient.classHier: unknown class #{className}")
    end

    def volNameFromPath(path)
      pa = path.split("/")
      return "vol0" unless pa[1] == "vol"
      return pa[2]
    end

    #
    # Hash volume information by volume name and volume path.
    #
    def hashVolumeInfo
      rh = {}
      volumeInfo.each do |vi|
        rh[vi.name]       = vi
        rh["/vol/#{vi.name}"] = vi
      end
      return rh
    end

    def volumeInfo
      rv = @conn.volume_list_info_iter_start
      begin
        tag = rv.tag
        retArr = []

        loop do
          rv = @conn.volume_list_info_iter_next(:maximum, @max_chunk, :tag, tag)
          return retArr if rv.records.to_i == 0
          retArr.concat(rv.volumes.volume_info.to_ary)
        end
      ensure
        @conn.volume_list_info_iter_end(:tag, tag)
      end
    end

    def lunInfo
      rv = @conn.lun_list_info
      return [] if rv.luns.kind_of?(String)
      return rv.luns.lun_info.to_ary
    end

    def aggrInfo
      rv = @conn.aggr_list_info(:verbose, true)
      return [] if rv.aggregates.kind_of?(String)
      return rv.aggregates.aggr_info.to_ary
    end

    #
    # Hash nfs export rules by path name.
    #
    def hashNfsExportRules
      rh = {}
      nfsExportRules.each do |ner|
        rh[ner.pathname] = ner
      end
      return rh
    end

    def nfsExportRules
      @conn.nfs_exportfs_list_rules(:persistent, true).rules.exports_rule_info.to_ary
    end

    #
    # Hash cifs shares by mount point.
    #
    def hashCifsShares
      rh = {}
      cifsShares.each do |cs|
        rh[cs.mount_point] = cs
      end
      return rh
    end

    def cifsShares
      rv = @conn.cifs_share_list_iter_start
      begin
        tag = rv.tag
        retArr = []

        loop do
          rv = @conn.cifs_share_list_iter_next(:maximum, @max_chunk, :tag, tag)
          return retArr if rv.records.to_i == 0
          retArr.concat(rv.cifs_shares.cifs_share_info.to_ary)
        end
      ensure
        @conn.cifs_share_list_iter_end(:tag, tag)
      end
    end

    def hashDiskInfo
      rh = {}
      diskInfo.each do |di|
        rh[di.name] = di
      end
      return rh
    end

    def diskInfo
      @conn.disk_list_info.disk_details.disk_detail_info.to_ary
    end

    def updateMetrics(statistic_time)
      @metricIdByKey = {}
      perfHash = collectPerf(statistic_time)

      topMe = agent.top_managed_elements.first
      topMe.elements_with_metrics.each do |se|
        updateMetricsForNode(se, perfHash)
      end unless topMe.nil?
    end

    def updateMetricsForNode(node, perfHash)
      className = node.class_name
      perf_obj_names = CLASS_TO_PERF_OBJECT_NAMES[className]

      ikeys = []
      metricHash = NmaHash.new
      metricHash.statistic_time = perfHash.statistic_time
      perf_obj_names.each do |pon|
        if (poh = perfHash[pon]).nil?
          $log.warn "#{self.class.to_s}.updateMetricsForNode: perf object type #{pon} not found for #{node.obj_name_str}"
          next
        end
        ikey = OBJECT_NAME_TO_INST_KEY[pon].call(node.type_spec_obj)
        if ikey.nil?
          metricHash[pon] = poh
        else
          if (iv = poh[ikey]).nil?
            $log.warn "#{self.class.to_s}.updateMetricsForNode: perf instance #{ikey} not found for #{node.obj_name_str}"
            return
          end
          ikeys << ikey
          metricHash[pon] = NmaHash.new { |h| h[ikey] = iv }
        end
      end

      fullKey = ikeys.sort.join(", ")
      if (metricId = @metricIdByKey[fullKey]).nil?
        metric = deriveMetrics(node, metricHash)
        @metricIdByKey[fullKey] = metric.id
      else
        #
        # Quick way to update node.metric_id without saving the serialized cols.
        #
        MiqCimInstance.where(:id => node.id).update_all(:metric_id => metricId) unless node.metric_id == metricId
      end
    end

    def deriveMetrics(node, metricHash)
      if (metric = node.metrics).nil?
        metric = getMetricForNode(node, metricHash)
      else
        pon = CLASS_TO_PERF_OBJECT_NAMES[node.class_name].first
        metric.derive_metrics(metricHash, counterInfo[pon])
      end
      return metric
    end

    def getMetricForNode(node, metricHash=nil)
      pon = CLASS_TO_PERF_OBJECT_NAMES[node.class_name].first

      case pon
      when "aggregate"
        metric = OntapAggregateMetric.new
      when "disk"
        metric = OntapDiskMetric.new
      when "LUN"
        metric = OntapLunMetric.new
      when "System"
        metric = OntapSystemMetric.new
      when "volume"
        metric = OntapVolumeMetric.new
      else
        metric = MiqCimMetric.new
      end
      metric.metric_obj = metricHash
      node.addNewMetric(metric)

      return metric
    end

    def getPerfData(objectname, counters=nil, instances=nil)
      rv = @conn.perf_object_get_instances_iter_start { |ah|
        ah.objectname = objectname
        ah.counters   = NmaHash.new { |h|
          h.counter = counters
        } unless counters.nil?
        ah.instances  = NmaHash.new { |h|
          h.instance  = instances
        } unless instances.nil?
      }
      begin
        tag     = rv.tag
        timestamp = rv.timestamp
        retArr = []

        loop do
          rv = @conn.perf_object_get_instances_iter_next(:maximum, @max_chunk, :tag, tag)
          return timestamp, retArr if rv.records.to_i == 0
          retArr.concat(rv.instances.instance_data.to_ary)
        end
      ensure
        @conn.perf_object_get_instances_iter_end(:tag, tag)
      end
    end

    def collectPerf(statistic_time)
      rh = NmaHash.new
      rh.statistic_time = statistic_time
      PERF_OBJECT_NAMES.each do |pon|
        oh = rh[pon]
        rh[pon] = oh = NmaHash.new unless oh
        ts, rv = getPerfData(pon, OBJECT_NAME_TO_COUNTERS[pon])
        rv.each do |inst|
          oh[inst.name] = ih = NmaHash.new
          ih.timestamp = ts
          ih.name = inst.name
          ih.counters = ch = NmaHash.new
          inst.counters.counter_data.to_ary.each do |ce|
            ch[ce.name] = ce.value
          end
        end
      end
      return rh
    end

    def getCounterInfoForObj(objectname)
      rv = @conn.perf_object_counter_list_info(:objectname, objectname)
      rh = NmaHash.new

      rv.counters.counter_info.to_ary.each do |ci|
        rh[ci.name] = ci
      end
      return rh
    end

    def getCounterInfo
      rh = NmaHash.new
      PERF_OBJECT_NAMES.each { |on| rh[on] = getCounterInfoForObj(on) }
      return rh
    end

    def counterInfo
      @@counterInfoLock.synchronize(:EX) do
        @@counterInfo = getCounterInfo if @@counterInfo.nil?
        return @@counterInfo
      end
    end

  end # class OntapClient

end # module MiqOntapClient

if $0 == "script/runner"

  require "util/MiqDumpObj"

  class NmaHash
    include MiqDumpObj
    def __dump
      dumpObj(self)
    end
  end

  class NmaArray
    include MiqDumpObj
    def __dump
      dumpObj(self)
    end
  end

  begin

    # SERVER    = "192.168.252.30"
    SERVER    = "192.168.252.169"
    USERNAME  = "root"
    PASSWORD  = "smartvm"

    include MiqOntapClient

    puts "Connecting to #{SERVER}..."
    oc = OntapClient.new(SERVER, USERNAME, PASSWORD)
    puts "done."

    puts "Version: #{oc.version_string}"
    puts
    # oc.counterInfo.__dump
    oc.updateOntap
    # oc.updateMetrics

  rescue => err
    puts err.to_s
    puts err.backtrace.join("\n")
  end

end
