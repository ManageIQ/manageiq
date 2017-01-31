require 'VMwareWebService/VimSyncDebug'
require 'sync'
require 'enumerator'
require 'VMwareWebService/MiqVimClientBase'
require 'VMwareWebService/MiqVimDump'
require 'VMwareWebService/VimPropMaps'

class MiqVimInventory < MiqVimClientBase
  attr_reader :cacheLock, :configLock

  alias_method :__connect, :connect
  alias_method :__disconnect, :disconnect

  include VimPropMaps
  include MiqVimDump

  @@selectorHash = {}
  @@cacheScope   = :cache_scope_full

  def initialize(server, username, password, cacheScope = nil)
    super(server, username, password)

    cacheScope ||= @@cacheScope

    case cacheScope
    when :cache_scope_full
      @propMap = FullPropMap
      $vim_log.info "MiqVimInventory: using property map FullPropMap"
    when :cache_scope_ems_refresh
      @propMap = EmsRefreshPropMap
      $vim_log.info "MiqVimInventory: using property map EmsRefreshPropMap"
    when :cache_scope_core
      @propMap = CorePropMap
      $vim_log.info "MiqVimInventory: using property map CorePropMap"
    when :cache_scope_event_monitor
      @propMap = EventMonitorPropMap
      $vim_log.info "MiqVimInventory: using property map EventMonitorPropMap"
    else
      @propMap = FullPropMap
      $vim_log.info "MiqVimInventory: unrecognized cache scope #{cacheScope}, using FullPropMap"
    end

    if @v2
      @propMap = dupProps(@propMap)

      deleteProperty(:HostSystem, "capability.storageVMotionSupported")
      deleteProperty(:HostSystem, "capability.vmotionWithStorageVMotionSupported")

      deleteProperty(:Datastore, "summary.uncommitted")

      deleteProperty(:VirtualMachine, "config.hardware.numCoresPerSocket")
      deleteProperty(:VirtualMachine, "summary.config.ftInfo.instanceUuids")
      deleteProperty(:VirtualMachine, "summary.storage.unshared")
      deleteProperty(:VirtualMachine, "summary.storage.committed")

      deleteProperty(:ClusterComputeResource, "configuration.dasConfig.admissionControlPolicy")
      if @v20
        deleteProperty(:VirtualMachine, "availableField")
        deleteProperty(:HostSystem, "config.dateTimeInfo")
      end
    else
      if @v4 && cacheScope != :cache_scope_event_monitor
        @propMap = dupProps(@propMap)
        addProperty(:VirtualMachine, "runtime.memoryOverhead")
        deleteProperty(:VirtualMachine, "config.hardware.numCoresPerSocket")
      end
      @propMap = @propMap.merge(PropMap4)
    end

    @propCol    = @sic.propertyCollector
    @rootFolder = @sic.rootFolder
    @objectSet  = objectSet
    @spec       = spec
    @updateSpec = updateSpec

    @globalIndent         = ""
    @selectorHash         = @@selectorHash
    @selectorPropPathHash = {}

    @cacheLock  = Sync.new
    @configLock = Sync.new

    # Un-comment to enable Sync lock debugging.
    # extend VimSyncDebug

    resetCache
    __connect
    @alive = true
  end # def initialize

  def addProperty(key, property)
    return if (pm = @propMap[key]).nil?
    property.split('.').each { |p| return if pm.include?(p) }
    @propMap[key][:props] << property
  end

  def deleteProperty(key, property)
    @propMap[key][:props].delete(property) unless @propMap[key].nil?
  end

  def self.cacheScope
    @@cacheScope
  end

  def self.cacheScope=(val)
    @@cacheScope = val
  end

  def logCacheCounts(pref)
    @cacheLock.synchronize(:SH) do
      @propMap.each_value do |pm|
        hn  = pm[:baseName]
        hnm = pm[:baseName] + "ByMor"

        unless instance_variable_get(hnm).nil?
          hnmc = instance_variable_get(hnm).keys.length
          $vim_log.info "#{pref}#{hnm}: #{hnmc}"
        end
        unless instance_variable_get(hn).nil?
          hnc = instance_variable_get(hn).keys.length
          $vim_log.info "#{pref}#{hn}: #{hnc}"
        end
      end
    end
  end

  def cacheStats(pref)
    totalCacheSz = 0
    @cacheLock.synchronize(:SH) do
      @propMap.each_value do |pm|
        hn        = pm[:baseName]
        hnm       = pm[:baseName] + "ByMor"
        hashByMor = instance_variable_get(hnm)
        hashByKey = pm[:keyPath] ? instance_variable_get(hn) : nil

        if hashByMor.nil?
          $vim_log.info "#{pref}#{hnm}: is nil"
          next
        end

        keya = hashByMor.keys
        obja = hashByMor.values
        $vim_log.info "#{pref}#{hnm}: #keys = #{keya.length}"
        $vim_log.info "#{pref}#{hnm}: #objects = #{obja.length}"
        obja.compact!
        obja.uniq!
        $vim_log.info "#{pref}#{hnm}: #unique non-nill objects = #{obja.length}"

        unless hashByKey.nil?
          keyb = hashByKey.keys
          objb = hashByKey.values
          $vim_log.info "#{pref}#{hn}: #keys = #{keyb.length}"
          $vim_log.info "#{pref}#{hn}: #objects = #{objb.length}"
          objb.compact!
          objb.uniq!
          $vim_log.info "#{pref}#{hn}: #unique non-nill objects = #{objb.length}"
          obja.concat(objb).uniq!
        end
        $vim_log.info "#{pref}TOTAL: #unique non-nill objects = #{obja.length}"
        cacheSz = Marshal.dump(obja).length
        $vim_log.info "#{pref}TOTAL: size of objects = #{cacheSz}"
        $vim_log.info "#{pref}****"
        totalCacheSz += cacheSz
      end
      $vim_log.info "#{pref}****************"
      $vim_log.info "#{pref}TOTAL: cache size = #{totalCacheSz}"
      $vim_log.info "#{pref}****************"
    end
    totalCacheSz
  end

  #
  # Construct an ObjectSpec to traverse the entire VI inventory tree.
  #
  def objectSet
    #
    # Traverse VirtualApp to Vm.
    #
    virtualAppTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "virtualAppTraversalSpec"
      ts.type = "VirtualApp"
      ts.path = "vm"
      ts.skip = "false"
    end unless @v2

    #
    # Traverse ResourcePool to ResourcePool and VirtualApp.
    #
    resourcePoolTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "resourcePoolTraversalSpec"
      ts.type      = "ResourcePool"
      ts.path      = "resourcePool"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
      end
    end

    #
    # Traverse ComputeResource to ResourcePool.
    #
    computeResourceRpTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "computeResourceRpTraversalSpec"
      ts.type      = "ComputeResource"
      ts.path      = "resourcePool"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "resourcePoolTraversalSpec" }
      end
    end

    #
    # Traverse ComputeResource to host.
    #
    computeResourceHostTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "computeResourceHostTraversalSpec"
      ts.type = "ComputeResource"
      ts.path = "host"
      ts.skip = "false"
    end

    #
    # Traverse Datacenter to host folder.
    #
    datacenterHostTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "datacenterHostTraversalSpec"
      ts.type      = "Datacenter"
      ts.path      = "hostFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to VM folder.
    #
    datacenterVmTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "datacenterVmTraversalSpec"
      ts.type      = "Datacenter"
      ts.path      = "vmFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to Datastore folder.
    #
    datacenterDsFolderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "dcTodf"
      ts.type      = "Datacenter"
      ts.path      = "datastoreFolder"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Datacenter to Datastore.
    #
    datacenterDsTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "datacenterDsTraversalSpec"
      ts.type = "Datacenter"
      ts.path = "datastore"
      ts.skip = "false"
    end

    #
    # Traverse Datacenter to Network folder
    #
    datacenterNetworkFolderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name = "dcTonf"
      ts.type = "Datacenter"
      ts.path = "networkFolder"
      ts.skip = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
      end
    end

    #
    # Traverse Folder to children.
    #
    folderTs = VimHash.new("TraversalSpec") do |ts|
      ts.name      = "folderTraversalSpec"
      ts.type      = "Folder"
      ts.path      = "childEntity"
      ts.skip      = "false"
      ts.selectSet = VimArray.new("ArrayOfSelectionSpec") do |ssa|
        ssa << VimHash.new("SelectionSpec") { |ss| ss.name = "folderTraversalSpec" }
        ssa << datacenterHostTs
        ssa << datacenterVmTs
        ssa << datacenterDsTs
        ssa << datacenterDsFolderTs
        ssa << datacenterNetworkFolderTs
        ssa << computeResourceRpTs
        ssa << computeResourceHostTs
        ssa << resourcePoolTs
        ssa << virtualAppTs unless @v2
      end
    end

    aOobjSpec = VimArray.new("ArrayOfObjectSpec") do |osa|
      osa << VimHash.new("ObjectSpec") do |os|
        os.obj       = @sic.rootFolder
        os.skip      = "false"
        os.selectSet = VimArray.new("ArrayOfSelectionSpec") { |ssa| ssa << folderTs }
      end
    end

    (aOobjSpec)
  end # def objectSet

  #
  # Construct an array of PropertySpec objects to retrieve the MORs for all the
  # inventory objects we're interested in.
  #
  # Most of thosse objects are subclasses of ManagedEntity, so they are all
  # covered by the first entry. Datastore is a special case that requires its
  # own entry.
  #
  def spec
    propSpecAry = VimArray.new("ArrayOfPropertySpec") do |psa|
      psa << VimHash.new("PropertySpec") do |ps|
        ps.type = "ManagedEntity"
        ps.all  = "false"
      end
      psa << VimHash.new("PropertySpec") do |ps|
        ps.type = "Datastore"
        ps.all  = "false"
      end
    end
    VimArray.new("ArrayOfPropertyFilterSpec") do |pfsa|
      pfsa << VimHash.new("PropertyFilterSpec") do |pfs|
        pfs.propSet   = propSpecAry
        pfs.objectSet = @objectSet
      end
    end
  end

  def updateSpecByPropMap(propMap)
    VimHash.new("PropertyFilterSpec") do |pfs|
      pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
        propMap.each do |type, h|
          psa << VimHash.new("PropertySpec") do |ps|
            ps.type    = type
            ps.all     = h[:props].nil?.to_s
            ps.pathSet = h[:props] if h[:props]
          end
        end
      end
      pfs.objectSet = @objectSet
    end
  end

  def updateSpec
    updateSpecByPropMap(@propMap)
  end

  def assert_no_locks
    return unless @lock_debug
    return unless @cacheLock.sync_locked?
    msg = ""
    msg += "Exclusive cache lock held\n" if @cacheLock.sync_exclusive?
    msg += "Shared cache lock held\n" if @cacheLock.sync_shared?
    msg += Kernel.caller.join("\n")
    raise msg
  end

  def loadCache
    @cacheLock.synchronize(:EX) do
      @propMap.each_value do |pm|
        send("#{pm[:baseName][1..-1]}_locked".to_sym)
      end
    end
  end

  def resetCache
    $vim_log.info "MiqVimInventory.resetCache: clearing cache for #{@connId}"
    @cacheLock.synchronize(:EX) do
      @inventoryHash = nil

      @propMap.each_value do |pm|
        instance_variable_set("#{pm[:baseName]}ByMor", nil)
        instance_variable_set(pm[:baseName], nil)
      end
    end
    $vim_log.info "MiqVimInventory.resetCache: cleared cache for #{@connId}"
  end # def resetCache

  def currentSession
    getMoProp(@sic.sessionManager, "currentSession")
  end

  def isAlive?
    return false unless @alive
    begin
        unless currentSession
          $vim_log.info "MiqVimInventory.isAlive?: Current session no longer exists."
          @alive = false
        end
      rescue Exception => err
        $vim_log.info "MiqVimInventory.isAlive?: Could not access connection - #{err}"
        @alive = false
      end
    @alive
  end

  #
  # For testing
  #
  def isDead
    @alive = false
  end

  def isVirtualCenter?
    @isVirtualCenter
  end

  def isHostAgent?
    !@isVirtualCenter
  end

  def hashObj(type, props)
    type = type.to_sym if type.kind_of?(String)
    raise "hashObj: exclusive cache lock not held" unless @cacheLock.sync_exclusive?
    raise "Unknown VIM object type: #{type}" unless (pmap = @propMap[type])

    return nil unless props

    baseName = pmap[:baseName]
    keyPath  = pmap[:keyPath]

    mor = props['MOR']
    if keyPath
      key = props.fetch_path(keyPath)
      if !key
        $vim_log.debug "hashObj: key is nil for #{mor}: #{keyPath}"
      elsif key.empty?
        $vim_log.debug "hashObj: key is empty for #{mor}: #{keyPath}"
        key = nil
        props.store_path(keyPath, nil)
      end
    else
      key = nil
    end

    if key
      objHash = instance_variable_get(baseName)
      objHash[key] = props
    end
    if mor
      objHash = instance_variable_get("#{baseName}ByMor")
      objHash[mor] = props
    end
    props
  end
  private :hashObj

  #
  # Add the property hash for the VIM object to the appropriate inventory hashes.
  #
  def addObjHash(objType, objHash)
    raise "addObjHash: exclusive cache lock not held" unless @cacheLock.sync_exclusive?

    objHash = hashObj(objType, objHash)
    objFixUp(objType, objHash)
  end

  def objFixUp(objType, objHash)
    objType = objType.to_sym if objType.kind_of? String

    #
    # Type-specific processing
    #
    case objType
    when :VirtualMachine
      #
      # The above hashObj call will hash by datastore path.
      # Below, we also hash by local path.
      #
      if (dsPath = objHash.fetch_path('summary', 'config', 'vmPathName'))
        localPath = localVmPath(dsPath)
        if localPath && !localPath.empty?
          objHash['summary']['config']['vmLocalPathName'] = localPath
          @virtualMachines[localPath] = objHash
        else
          objHash['summary']['config']['vmLocalPathName'] = nil
        end
      end

      if (ssObj = objHash["snapshot"])
        ssMorHash = VimHash.new
        rsl = ssObj['rootSnapshotList']
        rsl = [rsl] unless rsl.kind_of?(Array)
        rsl.each { |rs| snapshotFixup(rs, ssMorHash) }
        ssObj['ssMorHash'] = ssMorHash
      end

      if (hostMor = objHash.fetch_path('summary', 'runtime', 'host'))
        hostObj = hostSystemsByMor_locked[hostMor]
        return unless hostObj
        objHash['summary']["runtime"]["hostName"] = hostObj.fetch_path("summary", "config", "name")
      end

    when :ResourcePool
      objHash['summary']['name'] = objHash['name']
    end
  end

  def snapshotFixup(ssObj, ssMorHash)
    #
    # There can be more than one root snapshot.
    # When this is the case, ssObj is an array instead of a hash.
    #
    ssObj.each { |sso| snapshotFixup(sso, ssMorHash) } if ssObj.kind_of? Array

    #
    # Hash snapshot info by MOR.
    #
    ssMorHash[String.new(ssObj['snapshot'].to_s)] = ssObj

    #
    # Hash snapshot info by create time.
    #
    ssMorHash[ssObj['createTime']] = ssObj

    #
    # Ensure childSnapshotList is always present and always an array,
    # evne if it's empty.
    #
    childList = ssObj['childSnapshotList']
    if !childList
      ssObj['childSnapshotList'] = VimArray.new
    elsif !childList.kind_of? Array
      ssObj['childSnapshotList'] = VimArray.new { |a| a << childList }
    end

    ssObj['childSnapshotList'].each { |sso| snapshotFixup(sso, ssMorHash) }
  end

  #
  # Extract the properties for the VIM object represented by objMor and hash them.
  # Add the resulting property hash to the appropriate inventory hashes.
  #
  def addObjByMor(objMor)
    raise "addObjByMor: exclusive cache lock not held"      unless @cacheLock.sync_exclusive?
    objType = objMor.vimBaseType.to_sym
    raise "addObjByMor: Unknown VIM object type: #{objType}"  unless (pmap = @propMap[objType])

    objHash = getMoProp_local(objMor, pmap[:props])
    return nil unless objHash

    addObjHash(objType, objHash)
    objHash
  end

  def removeObjByMor(objMor)
    raise "removeObjByMor: exclusive cache lock not held"   unless @cacheLock.sync_exclusive?
    objType = objMor.vimBaseType.to_sym
    raise "removeObjByMor: Unknown VIM object type: #{objType}" unless (pmap = @propMap[objType])

    baseName  = pmap[:baseName]
    keyPath   = pmap[:keyPath]
    keyPath2  = pmap[:keyPath2]

    objHash = instance_variable_get("#{baseName}ByMor")
    return unless (props = objHash.delete(objMor))

    if keyPath
      key     = props.fetch_path(keyPath)
      key2    = keyPath2 ? props.fetch_path(keyPath2) : nil
      objHash = instance_variable_get(baseName)
      objHash.delete(key)
      objHash.delete(key2) if key2
    end
  end

  def propFromCache(hashName, key, props)
    props = [props] if props.kind_of?(String)
    @cacheLock.synchronize(:SH) do
      cv = send((hashName + "_locked").to_sym)[key]
      raise "propFromCache: key \"#{key}\" not found in hash #{hashName}" unless cv
      ppn = key
      props.each do |pn|
        cv = cv[pn]
        raise "propFromCache: property \"#{pn}\" not found under \"#{ppn}\"" unless cv
        ppn = pn
      end
      return(dupObj(cv))
    end
  end

  def allPropsFromCache(hashName, props)
    props = [props] if props.kind_of?(String)
    @cacheLock.synchronize(:SH) do
      ret = {}
      send((hashName + "_locked").to_sym).each do |key, cv|
        props.each do |pn|
          cv = cv[pn]
          break unless cv
        end
        ret[key] = cv
      end
      return(dupObj(ret))
    end
  end

  def keyFromCache(hashName, props, value = nil)
    raise "no block given" if value.nil? && !block_given?
    raise "block given with value" if !value.nil? && block_given?

    props = [props] if props.kind_of?(String)
    @cacheLock.synchronize(:SH) do
      ck, = send((hashName + "_locked").to_sym).detect do |_k, v|
        cv = v
        props.each do |pn|
          cv = cv[pn]
          break unless cv
        end
        block_given? ? yield(cv) : cv == value
      end
      return(dupObj(ck))
    end
  end

  def keyExistsInCache?(hashName, key)
    @cacheLock.synchronize(:SH) do
      return send((hashName + "_locked").to_sym).key?(key)
    end
  end

  ###################
  # Virtual Machines
  ###################

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def virtualMachines_locked
    raise "virtualMachines_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@virtualMachines) if @virtualMachines

    $vim_log.info "MiqVimInventory.virtualMachines_locked: loading VirtualMachine cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['VirtualMachine'], @propMap[:VirtualMachine][:props])

      @virtualMachines      = {}
      @virtualMachinesByMor = {}
      ra.each do |vmObj|
        addVirtualMachineObj(vmObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.virtualMachines_locked: loaded VirtualMachine cache for #{@connId}"

    @virtualMachines
  end # def virtualMachines_locked
  protected :virtualMachines_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def virtualMachinesByMor_locked
    raise "virtualMachinesByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@virtualMachinesByMor) if @virtualMachinesByMor
    virtualMachines_locked
    @virtualMachinesByMor
  end # def virtualMachinesByMor_locked
  protected :virtualMachinesByMor_locked

  #
  # Public accessor
  #
  def virtualMachines(selSpec = nil)
    vms = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        vms = dupObj(virtualMachines_locked)
      else
        vms = applySelector(virtualMachines_locked, selSpec)
      end
    end
    assert_no_locks
    vms
  end

  #
  # Public accessor
  #
  def virtualMachinesByMor(selSpec = nil)
    vms = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        vms = dupObj(virtualMachinesByMor_locked)
      else
        vms = applySelector(virtualMachinesByMor_locked, selSpec)
      end
    end
    assert_no_locks
    vms
  end

  #
  # Return a single VM object, given its MOR
  #
  def virtualMachineByMor(vmMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(virtualMachinesByMor_locked[vmMor])) if selSpec.nil?
      return(applySelector(virtualMachinesByMor_locked[vmMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of virtual machine objects that match the given property filter.
  #
  def virtualMachinesByFilter(filter)
    vms = nil
    @cacheLock.synchronize(:SH) do
      vms = applyFilter(virtualMachinesByMor_locked.values, filter)
      vms = dupObj(vms)
    end
    assert_no_locks
    vms
  end

  def addVirtualMachine(vmMor)
    @cacheLock.synchronize(:EX) do
      return(addObjByMor(vmMor))
    end
  end

  def refreshVirtualMachine(vmMor)
    @cacheLock.synchronize(:EX) do
      return(conditionalCopy(addObjByMor(vmMor)))
    end
  end

  def addVirtualMachineObj(vmObj)
    addObjHash(:VirtualMachine, vmObj)
  end
  protected :addVirtualMachineObj

  def removeVirtualMachine(vmMor)
    @cacheLock.synchronize(:EX) do
      removeObjByMor(vmMor)
    end
  end

  ####################
  # Compute Resources
  ####################

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def computeResources_locked
    raise "computeResources_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@computeResources) if @computeResources

    $vim_log.info "MiqVimInventory.computeResources_locked: loading ComputeResource cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['ComputeResource'], @propMap[:ComputeResource][:props])

      @computeResources      = {}
      @computeResourcesByMor = {}
      ra.each do |crObj|
        addObjHash(:ComputeResource, crObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.computeResources_locked: loaded ComputeResource cache for #{@connId}"

    @computeResources
  end # def computeResources_locked
  protected :computeResources_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def computeResourcesByMor_locked
    raise "computeResourcesByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@computeResourcesByMor) if @computeResourcesByMor
    computeResources_locked
    @computeResourcesByMor
  end # def computeResourcesByMor_locked
  protected :computeResourcesByMor_locked

  #
  # Public accessor
  #
  def computeResources(selSpec = nil)
    crs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        crs = dupObj(computeResources_locked)
      else
        crs = applySelector(computeResources_locked, selSpec)
      end
    end
    assert_no_locks
    crs
  end # def computeResources

  #
  # Public accessor
  #
  def computeResourcesByMor(selSpec = nil)
    crs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        crs = dupObj(computeResourcesByMor_locked)
      else
        crs = applySelector(computeResourcesByMor_locked, selSpec)
      end
    end
    assert_no_locks
    crs
  end # def computeResourcesByMor

  #
  # Return a single computeResource object, given its MOR
  #
  def computeResourceByMor(crMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(computeResourcesByMor_locked[crMor])) if selSpec.nil?
      return(applySelector(computeResourcesByMor_locked[crMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of compute resource objects that match the given property filter.
  #
  def computeResourcesByFilter(filter)
    crs = nil
    @cacheLock.synchronize(:SH) do
      crs = applyFilter(computeResourcesByMor_locked.values, filter)
      crs = dupObj(crs)
    end
    assert_no_locks
    crs
  end

  ############################
  # Cluster Compute Resources
  ############################

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def clusterComputeResources_locked
    raise "clusterComputeResources_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@clusterComputeResources) if @clusterComputeResources

    $vim_log.info "MiqVimInventory.clusterComputeResources_locked: loading ClusterComputeResource cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['ClusterComputeResource'], @propMap[:ClusterComputeResource][:props])

      @clusterComputeResources      = {}
      @clusterComputeResourcesByMor = {}
      ra.each do |crObj|
        addObjHash(:ClusterComputeResource, crObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.clusterComputeResources_locked: loaded ClusterComputeResource cache for #{@connId}"

    @clusterComputeResources
  end # def clusterComputeResources_locked
  protected :clusterComputeResources_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def clusterComputeResourcesByMor_locked
    raise "clusterComputeResourcesByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@clusterComputeResourcesByMor) if @clusterComputeResourcesByMor
    clusterComputeResources_locked
    @clusterComputeResourcesByMor
  end # def clusterComputeResourcesByMor_locked
  protected :clusterComputeResourcesByMor_locked

  #
  # Public accessor
  #
  def clusterComputeResources(selSpec = nil)
    ccrs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        ccrs = dupObj(clusterComputeResources_locked)
      else
        ccrs = applySelector(clusterComputeResources_locked, selSpec)
      end
    end
    assert_no_locks
    ccrs
  end # def clusterComputeResources

  #
  # Public accessor
  #
  def clusterComputeResourcesByMor(selSpec = nil)
    ccrs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        ccrs = dupObj(clusterComputeResourcesByMor_locked)
      else
        ccrs = applySelector(clusterComputeResourcesByMor_locked, selSpec)
      end
    end
    assert_no_locks
    ccrs
  end # def clusterComputeResourcesByMor

  #
  # Return a single clusterComputeResource object, given its MOR
  #
  def clusterComputeResourceByMor(ccrMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(clusterComputeResourcesByMor_locked[ccrMor])) if selSpec.nil?
      return(applySelector(clusterComputeResourcesByMor_locked[ccrMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of cluster compute resource objects that match the given property filter.
  #
  def clusterComputeResourcesByFilter(filter)
    crs = nil
    @cacheLock.synchronize(:SH) do
      crs = applyFilter(clusterComputeResourcesByMor_locked.values, filter)
      crs = dupObj(crs)
    end
    assert_no_locks
    crs
  end

  #################
  # Resource Pools
  #################

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def resourcePools_locked
    raise "resourcePools_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@resourcePools) if @resourcePools

    $vim_log.info "MiqVimInventory.resourcePools_locked: loading ResourcePool cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['ResourcePool'], @propMap[:ResourcePool][:props])

      @resourcePools      = {}
      @resourcePoolsByMor = {}
      ra.each do |rpObj|
        addObjHash(:ResourcePool, rpObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.resourcePools_locked: loaded ResourcePool cache for #{@connId}"

    @resourcePools
  end # def resourcePools_locked
  protected :resourcePools_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def resourcePoolsByMor_locked
    raise "resourcePoolsByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@resourcePoolsByMor) if @resourcePoolsByMor
    resourcePools_locked
    @resourcePoolsByMor
  end # def resourcePoolsByMor_locked
  protected :resourcePoolsByMor_locked

  #
  # Public accessor
  #
  def resourcePools(selSpec = nil)
    rp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        rp = dupObj(resourcePools_locked)
      else
        rp = applySelector(resourcePools_locked, selSpec)
      end
    end
    assert_no_locks
    rp
  end # def resourcePools

  #
  # Public accessor
  #
  def resourcePoolsByMor(selSpec = nil)
    rp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        rp = dupObj(resourcePoolsByMor_locked)
      else
        rp = applySelector(resourcePoolsByMor_locked, selSpec)
      end
    end
    assert_no_locks
    rp
  end # def resourcePoolsByMor

  #
  # Return a single resourcePool object, given its MOR
  #
  def resourcePoolByMor(rpMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(resourcePoolsByMor_locked[rpMor])) if selSpec.nil?
      return(applySelector(resourcePoolsByMor_locked[rpMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of resource pool objects that match the given property filter.
  #
  def resourcePoolsByFilter(filter)
    rps = nil
    @cacheLock.synchronize(:SH) do
      rps = applyFilter(resourcePoolsByMor_locked.values, filter)
      rps = dupObj(rps)
    end
    assert_no_locks
    rps
  end

  ##############
  # VirtualApps
  ##############

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def virtualApps_locked
    raise "virtualApps_locked: cache lock not held" unless @cacheLock.sync_locked?

    #
    # Not supported in v2.0 or v2.5
    #
    if @v2
      @virtualApps      = {}
      @virtualAppsByMor = {}
    end

    return(@virtualApps) if @virtualApps

    $vim_log.info "MiqVimInventory.virtualApps_locked: loading VirtualApp cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['VirtualApp'], @propMap[:VirtualApp][:props])

      @virtualApps      = {}
      @virtualAppsByMor = {}
      ra.each do |rpObj|
        addObjHash(:VirtualApp, rpObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.virtualApps_locked: loaded VirtualApp cache for #{@connId}"

    @virtualApps
  end # def virtualApps_locked
  protected :virtualApps_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def virtualAppsByMor_locked
    raise "virtualAppsByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@virtualAppsByMor) if @virtualAppsByMor
    virtualApps_locked
    @virtualAppsByMor
  end # def virtualAppsByMor_locked
  protected :virtualAppsByMor_locked

  #
  # Public accessor
  #
  def virtualApps(selSpec = nil)
    rp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        rp = dupObj(virtualApps_locked)
      else
        rp = applySelector(virtualApps_locked, selSpec)
      end
    end
    assert_no_locks
    rp
  end # def virtualApps

  #
  # Public accessor
  #
  def virtualAppsByMor(selSpec = nil)
    rp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        rp = dupObj(virtualAppsByMor_locked)
      else
        rp = applySelector(virtualAppsByMor_locked, selSpec)
      end
    end
    assert_no_locks
    rp
  end # def virtualAppsByMor

  #
  # Return a single virtualApp object, given its MOR
  #
  def virtualAppByMor(vaMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(virtualAppsByMor_locked[vaMor])) if selSpec.nil?
      return(applySelector(virtualAppsByMor_locked[vaMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of virtualApp objects that match the given property filter.
  #
  def virtualAppsByFilter(filter)
    rps = nil
    @cacheLock.synchronize(:SH) do
      rps = applyFilter(virtualAppsByMor_locked.values, filter)
      rps = dupObj(rps)
    end
    assert_no_locks
    rps
  end

  ##########
  # Folders
  ##########

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def folders_locked
    raise "folders_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@folders) if @folders

    $vim_log.info "MiqVimInventory.folders_locked: loading Folder cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['Folder'], @propMap[:Folder][:props])

      @folders      = {}
      @foldersByMor = {}
      ra.each do |fObj|
        addObjHash(:Folder, fObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.folders_locked: loaded Folder cache for #{@connId}"

    @folders
  end # def folders_locked
  protected :folders_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def foldersByMor_locked
    raise "foldersByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@foldersByMor) if @foldersByMor
    folders_locked
    @foldersByMor
  end # def foldersByMor_locked
  protected :foldersByMor_locked

  #
  # Public accessor
  #
  def folders(selSpec = nil)
    f = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        f = dupObj(folders_locked)
      else
        f = applySelector(folders_locked, selSpec)
      end
    end
    assert_no_locks
    f
  end # def folders

  #
  # Public accessor
  #
  def foldersByMor(selSpec = nil)
    f = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        f = dupObj(foldersByMor_locked)
      else
        f = applySelector(foldersByMor_locked, selSpec)
      end
    end
    assert_no_locks
    f
  end # def foldersByMor

  #
  # Return a single folder object, given its MOR
  #
  def folderByMor(fMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(foldersByMor_locked[fMor])) if selSpec.nil?
      return(applySelector(foldersByMor_locked[fMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of folder objects that match the given property filter.
  #
  def foldersByFilter(filter)
    f = nil
    @cacheLock.synchronize(:SH) do
      f = applyFilter(foldersByMor_locked.values, filter)
      f = dupObj(f)
    end
    assert_no_locks
    f
  end

  ##############
  # Datacenters
  ##############

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def datacenters_locked
    raise "datacenters_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@datacenters) if @datacenters

    $vim_log.info "MiqVimInventory.datacenters_locked: loading Datacenter cache for #{@connId}"
    begin
    @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

    ra = getMoPropMulti(inventoryHash_locked['Datacenter'], @propMap[:Datacenter][:props])

    @datacenters      = {}
    @datacentersByMor = {}
    ra.each do |dcObj|
      addObjHash(:Datacenter, dcObj)
    end
  ensure
    @cacheLock.sync_unlock if unlock
  end
    $vim_log.info "MiqVimInventory.datacenters_locked: loaded Datacenter cache for #{@connId}"

    @datacenters
  end # def datacenters_locked
  protected :datacenters_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def datacentersByMor_locked
    raise "datacentersByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@datacentersByMor) if @datacentersByMor
    datacenters_locked
    (@datacentersByMor)
  end # def datacentersByMor_locked
  protected :datacentersByMor_locked

  #
  # Public accessor
  #
  def datacenters(selSpec = nil)
    dc = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        dc = dupObj(datacenters_locked)
      else
        dc = applySelector(datacenters_locked, selSpec)
      end
    end
    assert_no_locks
    dc
  end # def datacenters

  #
  # Public accessor
  #
  def datacentersByMor(selSpec = nil)
    dc = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        dc = dupObj(datacentersByMor_locked)
      else
        dc = applySelector(datacentersByMor_locked, selSpec)
      end
    end
    assert_no_locks
    dc
  end # def datacentersByMor

  #
  # Return a single datacenter object, given its MOR
  #
  def datacenterByMor(dcMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(datacentersByMor_locked[dcMor])) if selSpec.nil?
      return(applySelector(datacentersByMor_locked[dcMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of datacenter objects that match the given property filter.
  #
  def datacentersByFilter(filter)
    dc = nil
    @cacheLock.synchronize(:SH) do
      dc = applyFilter(datacentersByMor_locked.values, filter)
      dc = dupObj(dc)
    end
    assert_no_locks
    dc
  end

  ###############
  # Host Systems
  ###############

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def hostSystems_locked
    raise "hostSystems_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@hostSystems) if @hostSystems

    $vim_log.info "MiqVimInventory.hostSystems_locked: loading HostSystem cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['HostSystem'], @propMap[:HostSystem][:props])

      @hostSystems        = {}
      @hostSystemsByMor   = {}
      ra.each do |hsObj|
        addHostSystemObj(hsObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.hostSystems_locked: loaded HostSystem cache for #{@connId}"

    @hostSystems
  end # def hostSystems_locked
  protected :hostSystems_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def hostSystemsByMor_locked
    raise "hostSystemsByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@hostSystemsByMor) if @hostSystemsByMor
    hostSystems_locked
    @hostSystemsByMor
  end # def hostSystemsByMor_locked
  protected :hostSystemsByMor_locked

  #
  # Public accessor
  #
  def hostSystems(selSpec = nil)
    hs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        hs = dupObj(hostSystems_locked)
      else
        hs = applySelector(hostSystems_locked, selSpec)
      end
    end
    assert_no_locks
    hs
  end # def hostSystems

  #
  # Public accessor
  #
  def hostSystemsByMor(selSpec = nil)
    hs = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        hs = dupObj(hostSystemsByMor_locked)
      else
        hs = applySelector(hostSystemsByMor_locked, selSpec)
      end
    end
    assert_no_locks
    hs
  end # def hostSystemsByMor

  #
  # Return a single hostSystem object, given its MOR
  #
  def hostSystemByMor(hsMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(hostSystemsByMor_locked[hsMor])) if selSpec.nil?
      return(applySelector(hostSystemsByMor_locked[hsMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of host system objects that match the given property filter.
  #
  def hostSystemsByFilter(filter)
    hs = nil
    @cacheLock.synchronize(:SH) do
      hs = applyFilter(hostSystemsByMor_locked.values, filter)
      hs = dupObj(hs)
    end
    assert_no_locks
    hs
  end

  def hostSystemsStorageDevice(hostMors, selSpec = nil)
    sd = getMoPropMulti(hostMors, "config.storageDevice")
    sd = applySelector(sd, selSpec) if selSpec

    sd
  end

  def addHostSystem(hsMor)
    @cacheLock.synchronize(:EX) do
      addObjByMor(hsMor)
    end
  end

  def addHostSystemObj(hsObj)
    addObjHash(:HostSystem, hsObj)
  end

  #############
  # Datastores
  #############

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dataStores_locked
    raise "dataStores_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dataStores) if @dataStores

    $vim_log.info "MiqVimInventory.dataStores_locked: loading Datastore cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['Datastore'], @propMap[:Datastore][:props])

      @dataStores      = {}
      @dataStoresByMor = {}
      ra.each do |dsObj|
        addDataStoreObj(dsObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.dataStores_locked: loaded Datastore cache for #{@connId}"

    @dataStores
  end # def dataStores_locked
  protected :dataStores_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dataStoresByMor_locked
    raise "dataStoresByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dataStoresByMor) if @dataStoresByMor
    dataStores_locked
    @dataStoresByMor
  end # def dataStoresByMor_locked
  protected :dataStoresByMor_locked

  #
  # Public accessor
  #
  def dataStores(selSpec = nil)
    ds = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        ds = dupObj(dataStores_locked)
      else
        ds = applySelector(dataStores_locked, selSpec)
      end
    end
    assert_no_locks
    ds
  end # def dataStores

  #
  # Public accessor
  #
  def dataStoresByMor(selSpec = nil)
    ds = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        ds = dupObj(dataStoresByMor_locked)
      else
        ds = applySelector(dataStoresByMor_locked, selSpec)
      end
    end
    assert_no_locks
    ds
  end # def dataStoresByMor

  #
  # Return a single hostSystem object, given its MOR
  #
  def dataStoreByMor(dsMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(dataStoresByMor_locked[dsMor])) if selSpec.nil?
      return(applySelector(dataStoresByMor_locked[dsMor], selSpec))
    end
  end

  #
  # Public accessor
  #
  # Return an array of data store objects that match the given property filter.
  #
  def dataStoresByFilter(filter)
    ds = nil
    @cacheLock.synchronize(:SH) do
      ds = applyFilter(dataStoresByMor_locked.values, filter)
      ds = dupObj(ds)
    end
    assert_no_locks
    ds
  end

  def dataStoresByFilter_local(filter)
    ds = nil
    @cacheLock.synchronize(:SH) do
      ds = applyFilter(dataStoresByMor_locked.values, filter)
      ds = deepClone(ds)
    end
    assert_no_locks
    ds
  end

  def addDataStore(dsMor)
    @cacheLock.synchronize(:EX) do
      addObjByMor(dsMor)
    end
  end

  def addDataStoreObj(dsObj)
    addObjHash(:Datastore, dsObj)
  end

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dvPortgroups_locked
    raise "dvPortgroups_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dvPortgroups) if @dvPortgroups

    $vim_log.info "MiqVimInventory.dvPortgroups_locked: loading DV Portgroup cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['DistributedVirtualPortgroup'], @propMap[:DistributedVirtualPortgroup][:props])

      @dvPortgroups      = {}
      @dvPortgroupsByMor = {}
      ra.each do |dvpObj|
        addDVPObj(dvpObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.dvPortgroups_locked: loaded DV Portgroup cache for #{@connId}"

    @dvPortgroups
  end # def dvPortgroups_locked
  protected :dvPortgroups_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dvPortgroupsByMor_locked
    raise "dvPortgroupsByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dvPortgroupsByMor) if @dvPortgroupsByMor
    dvPortgroups_locked
    @dvPortgroupsByMor
  end # def dvPortgroupsByMor_locked
  protected :dvPortgroupsByMor_locked

  #
  # Public accessor
  #
  def dvPortgroups(selSpec = nil)
    dvp = nil
    @cacheLock.synchronize(:SH) do
      dvp = if selSpec.nil?
              dupObj(dvPortgroups_locked)
            else
              applySelector(dvPortgroups_locked, selSpec)
            end
    end
    assert_no_locks
    dvp
  end # def dvPortgroups

  #
  # Public accessor
  #
  def dvPortgroupsByMor(selSpec = nil)
    dvp = nil
    @cacheLock.synchronize(:SH) do
      dvp = if selSpec.nil?
              dupObj(dvPortgroupsByMor_locked)
            else
              applySelector(dvPortgroupsByMor_locked, selSpec)
            end
    end
    assert_no_locks
    dvp
  end # def dvPortgroupsByMor

  #
  # Return a single storagePod object, given its MOR
  #
  def dvPortgroupByMor(dvpMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(dvPortgroupsByMor_locked[dvpMor])) if selSpec.nil?
      return(applySelector(dvPortgroupsByMor_locked[dvpMor], selSpec))
    end
  end

  def addDVPObj(dvpObj)
    addObjHash(:DistributedVirtualPortgroup, dvpObj)
  end

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dvSwitches_locked
    raise "dvSwitches_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dvSwithces) if @dvSwitches

    $vim_log.info "MiqVimInventory.dvSwitches_locked: loading DV Switch cache for #{@connId}"

    base_class    = 'DistributedVirtualSwitch'.freeze
    child_classes = VimClass.child_classes(base_class)

    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      moref_array = child_classes.collect { |klass| inventoryHash_locked[klass] }.flatten.compact

      ra = getMoPropMulti(moref_array, @propMap[base_class.to_sym][:props])

      @dvSwitches      = {}
      @dvSwitchesByMor = {}
      ra.each do |dvsObj|
        addDVSObj(dvsObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.dvSwitches_locked: loaded DV Switch cache for #{@connId}"

    @dvSwitches
  end # def dvSwitches_locked
  protected :dvSwitches_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def dvSwitchesByMor_locked
    raise "dvSwitchesByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@dvSwitchesByMor) if @dvSwitchesByMor
    dvSwitches_locked
    @dvSwitchesByMor
  end # def dvSwitchesByMor_locked
  protected :dvSwitchesByMor_locked

  #
  # Public accessor
  #
  def dvSwitches(selSpec = nil)
    dvs = nil
    @cacheLock.synchronize(:SH) do
      dvs = if selSpec.nil?
              dupObj(dvSwitches_locked)
            else
              applySelector(dvSwitches_locked, selSpec)
            end
    end
    assert_no_locks
    dvs
  end # def dvSwitches

  #
  # Public accessor
  #
  def dvSwitchesByMor(selSpec = nil)
    dvs = nil
    @cacheLock.synchronize(:SH) do
      dvs = if selSpec.nil?
              dupObj(dvSwitchesByMor_locked)
            else
              applySelector(dvSwitchesByMor_locked, selSpec)
            end
    end
    assert_no_locks
    dvs
  end # def dvSwitchesByMor

  #
  # Return a single DV Switch object, given its MOR
  #
  def dvSwitchByMor(dvsMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(dvSwitchesByMor_locked[dvsMor])) if selSpec.nil?
      return(applySelector(dvSwitchesByMor_locked[dvsMor], selSpec))
    end
  end

  def addDVSObj(dvsObj)
    addObjHash(:DistributedVirtualSwitch, dvsObj)
  end
  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def storagePods_locked
    raise "storagePods_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@storagePods) if @storagePods

    $vim_log.info "MiqVimInventory.storagePods_locked: loading Datastore Cluster cache for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      ra = getMoPropMulti(inventoryHash_locked['StoragePod'], @propMap[:StoragePod][:props])

      @storagePods      = {}
      @storagePodsByMor = {}
      ra.each do |dsObj|
        addStoragePodObj(dsObj)
      end
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.storagePods_locked: loaded Datastore Cluster cache for #{@connId}"

    @storagePods
  end # def storagePods_locked
  protected :storagePods_locked

  #
  # For internal use.
  # Must be called with cache lock held
  # Returns with the cache lock held - must be unlocked by caller.
  #
  def storagePodsByMor_locked
    raise "storagePodsByMor_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@storagePodsByMor) if @storagePodsByMor
    storagePods_locked
    @storagePodsByMor
  end # def storagePodsByMor_locked
  protected :storagePodsByMor_locked

  #
  # Public accessor
  #
  def storagePods(selSpec = nil)
    sp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        sp = dupObj(storagePods_locked)
      else
        sp = applySelector(storagePods_locked, selSpec)
      end
    end
    assert_no_locks
    sp
  end # def storagePods

  #
  # Public accessor
  #
  def storagePodsByMor(selSpec = nil)
    sp = nil
    @cacheLock.synchronize(:SH) do
      if selSpec.nil?
        sp = dupObj(storagePodsByMor_locked)
      else
        sp = applySelector(storagePodsByMor_locked, selSpec)
      end
    end
    assert_no_locks
    sp
  end # def storagePodsByMor

  #
  # Return a single storagePod object, given its MOR
  #
  def storagePodByMor(spMor, selSpec = nil)
    @cacheLock.synchronize(:SH) do
      return(dupObj(storagePodsByMor_locked[spMor])) if selSpec.nil?
      return(applySelector(storagePodsByMor_locked[spMor], selSpec))
    end
  end

  def addStoragePodObj(spObj)
    addObjHash(:StoragePod, spObj)
  end

  #
  # A hash of managed object references for all the objects we care about.
  #
  # For internal use. Locking handled by caller
  #
  def inventoryHash_locked
    raise "inventoryHash_locked: cache lock not held" unless @cacheLock.sync_locked?
    return(@inventoryHash) if @inventoryHash

    $vim_log.info "MiqVimInventory.inventoryHash_locked: loading inventoryHash for #{@connId}"
    begin
      @cacheLock.sync_lock(:EX) if (unlock = @cacheLock.sync_shared?)

      $vim_log.info "MiqVimInventory(#{@server}, #{@username}).inventoryHash_locked: calling retrieveProperties" if $vim_log
      rv = retrievePropertiesCompat(@propCol, @spec)
      $vim_log.info "MiqVimInventory(#{@server}, #{@username}).inventoryHash_locked: returned from retrieveProperties" if $vim_log
      @inventoryHash = {}
      rv.each { |v| (@inventoryHash[v.obj.vimType] ||= []) << v.obj }
    ensure
      @cacheLock.sync_unlock if unlock
    end
    $vim_log.info "MiqVimInventory.inventoryHash_locked: loaded inventoryHash for #{@connId}"

    @inventoryHash
  end

  def inventoryHash
    ih = nil
    @cacheLock.synchronize(:SH) do
      ih = dupObj(inventoryHash_locked)
    end
    ih
  end # def inventoryHash

  #
  # Generate a user event associated with the given managed object.
  #
  def logUserEvent(entity, msg)
    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).logUserEvent: calling logUserEvent" if $vim_log
    super(@sic.eventManager, entity, msg)
    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).logUserEvent: returned from logUserEvent" if $vim_log
  end

  ##################################
  # Datastore/path utility methods.
  ##################################

  def self.dsPath?(p)
    return true if p =~ /^\[[^\]]*\].*/
    false
  end

  def dsPath?(p)
    MiqVimInventory.dsPath?(p)
  end

  def self.path2dsName(p)
    return nil unless MiqVimInventory.dsPath?(p)
    p.gsub(/^\[([^\]]*)\].*/, '\1')
  end

  def path2dsName(p)
    MiqVimInventory.path2dsName(p)
  end

  def dsName2path(dsn)
    ret = nil
    @cacheLock.synchronize(:SH) do
      ret = dataStores_locked[dsn]['summary']["url"]
    end
    ret
  end

  def dsName2mo(dsn)
    ret = nil
    @cacheLock.synchronize(:SH) do
      ret = dupObj(dataStores_locked[dsn]['summary']["datastore"])
    end
    assert_no_locks
    ret
  end

  def dsName2mo_local(dsn)
    ret = nil
    @cacheLock.synchronize(:SH) do
      ret = dataStores_locked[dsn]['summary']["datastore"]
    end
    assert_no_locks
    ret
  end

  def self.dsRelativePath(p)
    raise "dsRelativePath: #{p} is not a datastore path" unless dsPath?(p)
    p.gsub(/^.*\]\s*/, '')
  end

  def dsRelativePath(p)
    MiqVimInventory.dsRelativePath(p)
  end

  def localVmPath(p)
    return p unless dsPath?(p)

    ds   = path2dsName(p)
    path = dsRelativePath(p)

    begin
      dsPath = dsName2path(ds)
    rescue => err
      return nil
    end

    return dsPath if !path || path == "/"
    File.join(dsPath, path)
  end # def localVmPath

  def datastorePath(p)
    return p if dsPath?(p)

    drp = nil
    @cacheLock.synchronize(:SH) do
      dataStores_locked.each do |n, o|
        if p[o['summary']['url']]
          drp = p.dup
          drp[o['summary']['url']] = "[#{n}] "
          break
        end
      end
    end
    raise "datastorePath: Could not find datastore for path #{p}" unless drp
    drp
  end

  def vmDatacenterName(vmMor)
    @cacheLock.synchronize(:SH) do
      datacentersByMor_locked.each do |_n, o|
        begin
          f = foldersByMor_locked[o['vmFolder']]
          fVms = f['childEntity']
          fVms.each do |vmMo|
            return o['name'] if vmMor == vmMo
          end
        rescue => err
          # Ignore errors, keep going and return nil if not found.
        end
      end
      return nil
    end
  end

  ##############################
  # Log and diagnostic methods.
  ##############################

  def queryLogDescriptions(host = nil)
    queryDescriptions(@sic.diagnosticManager, host)
  end

  def browseDiagnosticLog(key, start = nil, lines = nil, host = nil)
    super(@sic.diagnosticManager, host, key, start, lines)
  end

  def browseDiagnosticLogEx(key, start = nil, lines = nil, host = nil)
    # Continually loop over the browseDiagnosticLog to get the number of lines
    #   requested, since it returns 1000 lines by default, even if specified
    #   to be higher.  Setting lines to nil returns all lines, as per the
    #   documentation.
    rv = nil
    next_start = (start || 1)
    lines_left = lines

    loop do
      l = browseDiagnosticLog(key, next_start, lines_left, host)
      l['lineText'] ||= []

      unless rv.nil?
        rv['lineText'] += l['lineText']
      else
        rv = l
        rv['lineStart'] = rv['lineStart'].to_i
      end

      read_lines = l['lineText'].length
      break if read_lines != 1000
      if lines
        lines_left -= read_lines
        break if lines_left <= 0
      end

      next_start += read_lines
    end

    rv['lineText'] = rv['lineText'][0..lines - 1] if lines && rv['lineText'].length > lines
    rv['lineEnd'] = rv['lineStart'] + rv['lineText'].length - 1
    rv
  end

  ########################
  # Task utility methods.
  ########################

  def getTasks
    getMoProp_local(@sic.taskManager, "recentTask")['recentTask']
  end
  # private :getTasks

  def getTasksByFilter(filter)
    ta = applyFilter(getMoPropMulti(getTasks, 'info'), filter)
    dupObj(ta)
  end

  def getTaskMor(tmor)
    if tmor.respond_to?(:vimType)
      $vim_log.debug "getTaskMor: returning #{tmor}, no search"
      return tmor
    else
      $vim_log.debug "getTaskMor: searching for task #{tmor}"
      getTasks.each do |tmo|
        if tmo.to_str == tmor
          $vim_log.debug "getTaskMor: returning #{tmo} (#{tmo.vimType})"
          return tmo
        end
      end
      raise "getTaskMor: task #{tmor} not found."
    end
  end

  def cancelTask(tmor)
    super(getTaskMor(tmor))
  end

  def waitForTask(tmor, className = nil)
    className ||= self.class.to_s

    $vim_log.info "#{className}(#{@server}, #{@username})::waitForTask(#{tmor})" if $vim_log
    args = VimArray.new("ArrayOfPropertyFilterSpec") do |pfsa|
      pfsa << VimHash.new("PropertyFilterSpec") do |pfs|
        pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
          psa << VimHash.new("PropertySpec") do |ps|
            ps.type    = tmor.vimType
            ps.all     = "false"
            ps.pathSet = ["info.state", "info.error", "info.result"]
          end
        end
        pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
          VimHash.new("ObjectSpec") do |os|
            os.obj = tmor
            osa << os
          end
        end
      end
    end

    state = result = error = nil

    until state
      oca = retrievePropertiesCompat(@propCol, args)
      raise "waitForTask: task not found #{tmor}" if !oca || !oca[0] || !oca[0].propSet

      oca[0].propSet.each do |ps|
        if ps.name == "info.state"
          state = ps.val if ps.val == TaskInfoState::Success || ps.val == TaskInfoState::Error
        end
        error  = ps.val if ps.name == "info.error"
        result = ps.val if ps.name == "info.result"
      end
      sleep 1 unless state
    end

    raise VimFault.new(error) if state == TaskInfoState::Error
    $vim_log.info "#{className}(#{@server}, #{@username})::waitForTask: result = #{result}" if $vim_log
    result
  end # def waitForTask

  def pollTask(tmor, className = nil)
    className ||= self.class.to_s

    $vim_log.info "#{className}(#{@server}, #{@username})::pollTask(#{tmor})" if $vim_log
    args = VimArray.new("ArrayOfPropertyFilterSpec") do |pfsa|
      pfsa << VimHash.new("PropertyFilterSpec") do |pfs|
        pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
          psa << VimHash.new("PropertySpec") do |ps|
            ps.type    = tmor.vimType
            ps.all     = "false"
            ps.pathSet = ["info.state", "info.error", "info.result", "info.progress"]
          end
        end
        pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
          VimHash.new("ObjectSpec") do |os|
            os.obj = tmor
            osa << os
          end
        end
      end
    end

    state = result = error = progress = nil

    oca = retrievePropertiesCompat(@propCol, args)
    raise "pollTask: task not found #{tmor}" if !oca || !oca[0] || !oca[0].propSet

    oca[0].propSet.each do |ps|
      case ps.name
      when "info.state"
        state = ps.val
      when "info.error"
        error = ps.val
      when "info.result"
        result = ps.val
      when "info.progress"
        progress = ps.val
      end
    end

    case state
    when TaskInfoState::Error
      raise error.localizedMessage
    when TaskInfoState::Success
      return state, result
    when TaskInfoState::Running
      return state, progress
    else
      return state, nil
    end
  end # def pollTask

  ##############################
  # Property retrieval methods.
  ##############################

  #
  # Retrieve the properties for a single object, given its managed object reference.
  #
  def getMoProp_local(mo, path = nil)
    pfSpec = VimHash.new("PropertyFilterSpec") do |pfs|
      pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
        psa << VimHash.new("PropertySpec") do |ps|
          ps.type = mo.vimType
          if !path
            ps.all = "true"
          else
            ps.all = "false"
            ps.pathSet = path
          end
        end
      end
      pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
        osa << VimHash.new("ObjectSpec") do |os|
          os.obj = mo
        end
      end
    end

    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).getMoProp_local: calling retrieveProperties(#{mo.vimType})" if $vim_log
    oca = retrievePropertiesCompat(@propCol, pfSpec)
    $vim_log.info "MiqVimInventory(#{@server}, #{@username}).getMoProp_local: return from retrieveProperties(#{mo.vimType})" if $vim_log

    return nil if !oca || !oca[0] || !oca[0].propSet

    oc = oca[0]
    oc.MOR = oc.obj
    oc.delete('obj')

    oc.propSet = Array(oc.propSet) unless oc.propSet.kind_of?(Array)
    oc.propSet.each do |ps|
      #
      # Here, ps.name can be a property path in the form: a.b.c
      # If that's the case, we should set the target to: propHash['a']['b']['c']
      # creating intermediate nodes as needed.
      #
      h, k = hashTarget(oc, ps.name)
      if !h[k]
        h[k] = ps.val
      elsif h[k].kind_of? Array
        h[k] << ps.val
      else
        h[k] = VimArray.new do |arr|
          arr << h[k]
          arr << ps.val
        end
      end
    end # oc.propSet.each
    oc.delete('propSet')

    oc
  end

  #
  # Public accessor
  #
  def getMoProp(mo, path = nil)
    getMoProp_local(mo, path)
  end

  #
  # Retrieve the properties for multiple objects of the same type,
  # given an array of managed object references.
  #
  def getMoPropMulti(moa, path = nil)
    return [] if !moa || moa.empty?
    tmor = moa.first
    raise "getMoPropMulti: item is not a managed object reference" unless tmor.respond_to? :vimType

    args = VimArray.new("ArrayOfPropertyFilterSpec") do |pfsa|
      pfsa << VimHash.new("PropertyFilterSpec") do |pfs|
        pfs.propSet = VimArray.new("ArrayOfPropertySpec") do |psa|
          psa << VimHash.new("PropertySpec") do |ps|
            ps.type = tmor.vimType
            if !path
              ps.all = "true"
            else
              ps.all = "false"
              ps.pathSet = path
            end
          end
        end

        pfs.objectSet = VimArray.new("ArrayOfObjectSpec") do |osa|
          moa.each do |mor|
            VimHash.new("ObjectSpec") do |os|
              os.obj = mor
              osa << os
            end
          end
        end
      end
    end

    begin
      oca = retrievePropertiesCompat(@propCol, args)
    rescue HTTPClient::ReceiveTimeoutError => rte
      $vim_log.info "MiqVimInventory(#{@server}, #{@username}).getMoPropMulti: retrieveProperties timed out, reverting to getMoPropMultiIter" if $vim_log
      return getMoPropMultiIter(moa, path)
    end

    return [] unless oca

    oca = VimArray.new { |va| va << oca } unless oca.kind_of?(Array)
    oca.each do |oc|
      oc.MOR = oc.obj
      oc.delete('obj')

      oc.propSet = Array(oc.propSet) unless oc.propSet.kind_of?(Array)
      oc.propSet.each do |ps|
        #
        # Here, ps.name can be a property path in the form: a.b.c
        # If that's the case, we should set the target to: propHash['a']['b']['c']
        # creating intermediate nodes as needed.
        #
        h, k = hashTarget(oc, ps.name)
        if !h[k]
          h[k] = ps.val
        elsif h[k].kind_of? Array
          h[k] << ps.val
        else
          h[k] = VimArray.new do |arr|
            arr << h[k]
            arr << ps.val
          end
        end
      end # oc.propSet.each
      oc.delete('propSet')
    end

    oca
  end # def getMoPropMulti

  def getMoPropMultiIter(moa, path = nil)
    oca = []
    moa.each do |mo|
      oc = getMoProp_local(mo, path)
      oca << oc if oc
    end
    oca
  end

  def self.setSelector(selSpec)
    raise "MiqVimBroker.setSelector: selSpec must be a hash, received #{selSpec.class}" unless selSpec.kind_of?(Hash)
    selSpec.each_key do |k|
      raise "MiqVimBroker.setSelector: selSpec keys must be symbols, received #{k.class}" unless k.kind_of?(Symbol)
    end
    ov = nil
    selSpec.each_value do |v|
      if v.kind_of?(Array)
        v.each do |vv|
          unless vv.kind_of?(String)
            ov = vv
            break
          end
        end
      else
        ov = v unless v.kind_of?(String)
      end
      raise "MiqVimBroker.setSelector: selSpec values must be strings or arrays of strings, received #{ov.class}" unless ov.nil?
    end
    @@selectorHash.merge!(selSpec)
  end

  def self.removeSelector(selName)
    remKeys = nil
    if selName.kind_of?(Symbol)
      remKeys = [selName]
    elsif selName.kind_of?(Hash)
      remKeys = selName.keys
    elsif selName.kind_of?(Array)
      remKeys = selName
    else
      raise "MiqVimBroker.removeSelector: selName must be a symbol, hash or array, received #{selName.class}"
    end
    remKeys.each do |rk|
      raise "MiqVimBroker.removeSelector: keys must be symbols, received #{rk.class}" unless rk.kind_of?(Symbol)
    end

    remKeys.each do |rk|
      @@selectorHash.delete(rk)
    end
  end

  def setSelector(selSpec)
    raise "setSelector: selSpec must be a hash, received #{selSpec.class}" unless selSpec.kind_of?(Hash)
    selSpec.each_key do |k|
      raise "setSelector: selSpec keys must be symbols, received #{k.class}" unless k.kind_of?(Symbol)
    end
    ov = nil
    selSpec.each_value do |v|
      if v.kind_of?(Array)
        v.each do |vv|
          unless vv.kind_of?(String)
            ov = vv
            break
          end
        end
      else
        ov = v unless v.kind_of?(String)
      end
      raise "setSelector: selSpec values must be strings or arrays of strings, received #{ov.class}" unless ov.nil?
    end

    @configLock.synchronize(:EX) do
      @selectorHash.merge!(selSpec) { |k, _o, n| @selectorPropPathHash.delete(k); n }
    end
  end

  def getSelector(selName)
    raise "getSelector: selName must be a symbol, received #{selName.class}" unless selName.kind_of?(Symbol)

    @configLock.synchronize(:SH) do
      return @selectorHash[selName]
    end
  end

  def removeSelector(selName)
    remKeys = nil
    if selName.kind_of?(Symbol)
      remKeys = [selName]
    elsif selName.kind_of?(Hash)
      remKeys = selName.keys
    elsif selName.kind_of?(Array)
      remKeys = selName
    else
      raise "removeSelector: selName must be a symbol, hash or array, received #{selName.class}"
    end
    remKeys.each do |rk|
      raise "removeSelector: keys must be symbols, received #{rk.class}" unless rk.kind_of?(Symbol)
    end

    @configLock.synchronize(:EX) do
      remKeys.each do |rk|
        @selectorHash.delete(rk)
        @selectorPropPathHash.delete(rk)
      end
    end
  end

  def getSelSpec(selSpec)
    ss = selSpec
    if ss.kind_of?(Symbol)
      ss = getSelector(ss)
      raise "getSelSpec: selector #{selSpec} not found" if ss.nil?
    end
    ss = [] if ss.nil?
    ss.kind_of?(Array) ? ss : [ss]
  end

  def selSpecToPropPath(selSpec)
    return ss2pp(selSpec) unless selSpec.kind_of?(Symbol)

    @configLock.synchronize(:EX) do
      pp = @selectorPropPathHash[selSpec]
      return pp unless pp.nil?

      ss = getSelSpec(selSpec)
      raise "selSpecToPropPath: selector #{selSpec} not found" if ss.nil?

      return (@selectorPropPathHash[selSpec] = ss2pp(ss))
    end
  end

  def ss2pp(ss)
    getSelSpec(ss).collect { |s| s.split("[")[0] }.uniq
  end
  private :ss2pp

  def applySelector(topObj, selSpec)
    selSpec = getSelSpec(selSpec)

    if topObj.kind_of?(VimHash)
      retObj = VimHash.new(topObj.xsiType, topObj.vimType)

      selSpec.each do |cs|
        applySelSpec(topObj, retObj, splitPropPath(cs))
      end
    #
    # When passed a collection of objects at the top level, apply
    # the selSpec to each object in the collection, returning a
    # new collection of new objects.
    #
    elsif topObj.kind_of?(Hash)
      retObj = {}
      topObj.each do |k, v|
        retObj[k] = applySelector(v, selSpec)
      end
    elsif topObj.kind_of?(VimArray)
      retObj = VimArray.new(topObj.xsiType, topObj.vimType)
      topObj.each do |v|
        retObj << applySelector(v, selSpec)
      end
    end

    retObj
  end

  def applySelSpec(topObj, retObj, pa)
    prop, arrayKey = tagAndKey(pa.first)
    return unless topObj.kind_of?(Hash) && topObj.key?(prop)
    nextTopObj = topObj[prop]
    return if nextTopObj.nil?

    if pa.length == 1
      retObj[prop] = nextTopObj
      return
    end

    nextpa = pa[1..-1]

    if arrayKey == "*"
      raise "applySelSpec: #{pa.first} is not an array." unless nextTopObj.kind_of?(Array)
      retObj[prop] = VimArray.new(nextTopObj.xsiType, nextTopObj.vimType) if retObj[prop].nil?
      nextRetObj   = retObj[prop]

      nextTopObj.each_with_index do |ntoe, i|
        if (nroe = nextRetObj[i]).nil?
          nroe = nextRetObj[i] = VimHash.new(ntoe.xsiType, ntoe.vimType)
        end
        applySelSpec(ntoe, nroe, nextpa)
      end
    else
      retObj[prop] = VimHash.new(nextTopObj.xsiType, nextTopObj.vimType) if retObj[prop].nil?
      applySelSpec(nextTopObj, retObj[prop], nextpa)
    end
  end

  def applyFilter(objArr, propFilter)
    retArr = []

    objArr.each do |obj|
      match = true
      propFilter.each do |pn, pv|
        pVal = propValue(obj, pn)
        if pVal.kind_of?(Array)
          nxt = false
          pVal.each do |v|
            if pv === v
              nxt = true
              break
            end
          end
          next if nxt
        else
          next if pv === pVal
        end

        match = false
        break
      end
      retArr << obj if match
    end
    retArr
  end

  def propValue(baseHash, prop)
    return baseHash[prop] unless prop.index('.')

    h  = baseHash
    ka = splitPropPath(prop)
    ka[0...-1].each do |k|
      k, arrayKey = tagAndKey(k)
      if arrayKey
        array, idx = getVimArrayEnt(h[k], arrayKey, false)
        return(nil) unless array
        h = array[idx]
      else
        return(nil) unless h[k]
        h = h[k]
      end
    end
    (h[ka[-1]])
  end

  def hasProp?(baseHash, prop)
    return baseHash.key?(prop) unless prop.index('.')

    h  = baseHash
    ka = splitPropPath(prop)
    ka[0...-1].each do |k|
      k, arrayKey = tagAndKey(k)
      if arrayKey
        array, idx = getVimArrayEnt(h[k], arrayKey, false)
        return(false) unless array
        h = array[idx]
      else
        return(false) unless h[k]
        h = h[k]
      end
    end
    h.key?(ka[-1])
  end

  #
  # Here, keyString can be a property path in the form: a.b.c
  # If that's the case, return baseHash['a']['b'] for the hash, and 'c' for the key
  # creating intermediate nodes as needed.
  #
  def hashTarget(baseHash, keyString, create = false)
    return baseHash, keyString unless keyString.index('.')

    h  = baseHash
    ka = splitPropPath(keyString)
    ka[0...-1].each do |k|
      k, arrayKey = tagAndKey(k)
      if arrayKey
        array, idx = getVimArrayEnt(h[k], arrayKey, create)
        raise "hashTarget: Could not traverse tree through array element #{k}[#{arrayKey}] in #{keyString}" unless array
        h = array[idx]
      else
        h[k] = VimHash.new unless h[k]
        h = h[k]
      end
    end
    return h, ka[-1]
  end
  private :hashTarget

  #
  # Array keys (between "[" and "]") can contain ".", so we can't just use split.
  #
  def splitPropPath(propPath)
    pathArray = []
    inKey     = false
    pc        = ''

    propPath.split(//).each do |c|
      case c
      when '.'
        unless inKey
          pathArray << pc
          pc = ''
          next
        end
      when '['
        inKey = true
      when ']'
        inKey = false
      end
      pc << c
    end
    pathArray << pc unless pc.empty?

    pathArray
  end
  private :splitPropPath

  def tagAndKey(propStr)
    return propStr, nil unless propStr.include? '['

    if propStr =~ /([^\[]+)\[([^\]]+)\]/
      tag, key = $1, $2
    else
      raise "tagAndKey: malformed property string #{propStr}"
    end
    key = key[1...-1] if key[0, 1] == '"' && key[-1, 1] == '"'
    return tag, key
  end
  private :tagAndKey

  def getVimArrayType(arrayProp)
    return nil if !arrayProp.respond_to?(:xsiType) || !(typeStr = arrayProp.xsiType)
    return $1 if typeStr =~ /^ArrayOf(.*)$/
    nil
  end
  private :getVimArrayType

  def addToCollection(hash, tag, val)
    unless (array = hash[tag])
      array = VimArray.new
      if (type = val.xsiType)
        nh            = VimHash.new
        array.xsiType = "ArrayOf#{type}"
        nh[type]      = array
        hash[tag]     = nh
      end
      hash[tag] = array
    end
    array << val
  end

  #
  # Return array and index?
  #
  def getVimArrayEnt(arrayProp, key, create = false)
    return nil, nil     unless arrayProp.kind_of?(Array)

    if getVimArrayType(arrayProp) == 'ManagedObjectReference'
      arrayProp.each_index { |n| return arrayProp, n if arrayProp[n] == key }
    else
      hasKey = false
      arrayProp.each_index do |n|
        next unless (h = arrayProp[n]).kind_of? Hash
        if h.key?('key')
          hasKey = true
          return arrayProp, n if h['key'] == key
        end
      end
      unless hasKey
        begin
          nkey = Integer(key)
          return arrayProp, nkey
        rescue
        end
      end
      if create
        h = VimHash.new
        h['key'] = key
        arrayProp << h
        return arrayProp, (arrayProp.length - 1)
      end
    end
    return nil, nil
  end
  private :getVimArrayEnt

  ##########################
  # Object utility methods.
  ##########################

  #
  # When used in the broker - DRB - this method is redefined
  # to carry the cacheLock into the DRB dump method.
  #
  # When not used in the broker, there is no need to copy the object.
  #
  def dupObj(obj)
    obj
  end

  #
  # When used in the broker - DRB - this method is redefined
  # to create a deep clone of the object.
  #
  def conditionalCopy(obj)
    obj
  end

  def deepClone(obj)
    return nil unless obj
    nObj = obj.class.new
    nObj.vimType = obj.vimType if obj.respond_to?(:vimType)
    nObj.xsiType = obj.xsiType if obj.respond_to?(:xsiType)

    if obj.kind_of?(Hash)
      obj.each { |k, v| nObj[k] = deepClone(v) }
    elsif obj.kind_of?(Array)
      obj.each { |v| nObj << deepClone(v) }
    elsif obj.kind_of?(String)
      nObj.replace(obj)
    else
      raise "deepClone: unexpected object #{obj.class}"
    end

    nObj
  end
end
