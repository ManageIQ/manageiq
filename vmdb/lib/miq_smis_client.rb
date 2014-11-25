require 'rubygems'
require 'wbem'
require 'cgi'
require 'socket'
require 'miq_storage_defs'

module MiqSmisClient

  class SmisClient
    attr_reader :server, :conn, :managedElements, :meNameToProfile

    include MiqStorageDefs

    OperationalStatusNoContact      = 12
    OperationalStatusLostCommunication  = 13

    include WBEM

    @@classTable    = {}  # Classes hashed by classname.

    #
    # Exported elements.
    #
    @@fsToUrl     = {}
    @@urlToMe     = {}
    @@nfsHash     = {}

    @@classHierHash   = {}
    @@pruneUnless   = []
    @@globalIndent    = ""

    @@serverCalls = Hash.new { |h,k| h[k] = 0 }

    def self.serverCalls
      @@serverCalls
    end

    def self.classTable
      @@classTable
    end

    def self.pruneUnless
      @@pruneUnless
    end

    def self.fsToUrl
      @@fsToUrl
    end

    def self.urlToMe
      @@urlToMe
    end

    def self.nfsHash
      @@nfsHash
    end

    def self.getVFilters(prof, vFilters)
      prof = [ prof ] unless prof.kind_of?(Array)

      prof.each do |p|
        vFilters << p[:flags][:pruneUnless] if p[:flags][:pruneUnless]
        getVFilters(p[:next], vFilters) if p[:next]
      end
    end

    def initialize(server, username, password)
      @currentTopElement = nil
      $mw = self
      @server   = server
      @username = username
      @password = password
      @conn = WBEMConnection.new("https://#{server}", [username, password], 'interop')
      #
      # Get a list of all the profiles registered to the agent.
      # We make this call here, instead of in update_smis, to check if the WBEMConnection
      # can be established. The connection isn't made until the first request.
      #
      @pia = EnumerateInstanceNames('CIM_RegisteredProfile')
    end

    def update_smis(extProf)
      @agent = MiqSmisAgent.add(@server, @username, @password, MiqSmisAgent::DEFAULT_AGENT_TYPE)

      topLevelProfiles = []

      @pia.each do |pi|
        #
        # For each registered profile, get a list of all profiles the reference it.
        # "Dependent" - is the role of the source object.
        # "Antecedent"  - is the role of the returned objects.
        #
        rp = AssociatorNames(pi,  :AssocClass   => 'CIM_ReferencedProfile',
                      :ResultClass  => 'CIM_RegisteredProfile',
                      :Role     => "Dependent",
                      :ResultRole   => "Antecedent")

        #
        # If no other profiles reference this one, then it's a top-level profile.
        #
        topLevelProfiles << pi if !rp || rp.length == 0
      end

      @managedElements  = []
      @meNameToProfile  = {}

      topLevelProfiles.each do |apn|
        api = GetInstance(apn, :LocalNamespacePath => apn.namespace, :IncludeQualifiers => 'true')
        mes = AssociatorNames(apn,  :AssocClass   => 'CIM_ElementConformsToProfile',
                      :ResultClass  => 'CIM_System')

        #
        # Skip profiles that don't have any CIM_System managed elements.
        #
        next if mes.length == 0

        mes.each do |me|
          me.host = nil
          unless (pa = @meNameToProfile[me])
            dnss = self.default_namespace
            self.default_namespace = me.namespace
            mei = GetInstance(me)

            skip = false
            unless mei
              $log.info "MiqSmisClient: (nil) skipping #{me}"
              skip = true
            else
              mei['OperationalStatus'].each do |os|
                if os.value == OperationalStatusNoContact || os.value == OperationalStatusLostCommunication
                  $log.info "MiqSmisClient: (OperationalStatus) skipping #{me}"
                  skip = true
                  break
                end
              end
            end
            if skip
              self.default_namespace = dnss
              next
            end
            $log.info "MiqSmisClient: saving #{me}"

            @meNameToProfile[me] = [ api['RegisteredName'] ]
            node, prior_status = newNode(nil, me, true)
            self.default_namespace = dnss

            next if prior_status == STORAGE_UPDATE_OK

            @managedElements << node
          else
            pa << api['RegisteredName'] unless pa.include? api['RegisteredName']
          end
        end
      end

      collectData(extProf)
    end

    def metricManagerInit
      @managedElements.each do |me|
        self.default_namespace = me.objName.namespace
        SmisMetricManager.new(me)
      end
    end

    def collectData(prof)
      @managedElements.each do |me|
        @currentTopElement = me
        self.default_namespace = me.namespace
        traverseProfile(prof, me)
      end
    end

    def obj2ObjName(obj)
      cn = obj.classname.to_s
      unless (ch = SmisClient.classTable[cn])
        co = GetClass(cn, :IncludeQualifiers => true)
        keys = []
        co.properties.each do |pn, pv|
          keys << pn if pv.qualifiers['key']
        end
        SmisClient.classTable[cn] = ch = { :classObj => co, :keyProps => keys }
      end

      keyBindings = {}
      ch[:keyProps].each do |pn|
        keyBindings[pn] = obj.properties[pn].value
      end

      WBEM::CIMInstanceName.new(obj.classname, keyBindings, nil, @conn.default_namespace)
    end

    def newNode(obj, objName=nil, topMe=false)
      raise "newNode: Both obj and objName are nil" unless obj || objName
      objName ||= obj2ObjName(obj)
      objNameStr = objName.to_s

      obj = @conn.GetInstance(objName, :LocalNamespacePath => objName.namespace) unless obj

      node = MiqCimInstance.find_by_obj_name_str(objNameStr)

      #
      # This is the first time we've encountered this node. Add it to the database.
      #
      if node.nil?
        node = MiqCimInstance.new
        className         = obj.classname.to_s
        node.class_name       = className
        node.class_hier       = classHier(className)
        node.namespace        = objName.namespace
        node.obj_name       = objName
        node.obj_name_str     = objNameStr
        node.obj          = obj
        node.source         = "SMIS"
        node.is_top_managed_element = topMe
        node.top_managed_element  = @currentTopElement
        node.agent          = @agent
        node.zone_id        = @agent.zone_id
        node.last_update_status   = STORAGE_UPDATE_OK
        t = node.typeFromClassHier
        node.type         = t if t
        @agent.top_managed_elements << node if topMe
        node.save

        if (s = getAssociatedMetrics(objName))
          if s['StatisticTime'].to_i == 0
            nn = MiqCimInstance.find(node.id) # get the proper sub-class
            $log.info "SmisClient.newNode: zero StatisticTime for (#{nn.class}, #{nn.id}, #{nn.evm_display_name})"
          else
            metric = MiqCimMetric.new
            metric.metric_obj = s
            metric.miq_cim_instance = node
            node.metrics = metric
            @currentTopElement.elements_with_metrics << node
            metric.save
          end
        end

        return node, STORAGE_UPDATE_NEW
      end

      #
      # This node has already been updated through another agent
      # (or this agent through different storage device).
      #
      # XXX NOTE: if node.last_update_status == STORAGE_UPDATE_OK
      #   We may need to check if node.top_managed_element != @currentTopElement.
      #   This would indicate that more tha one storage system is claiming ownership
      #   of the node. This may be the case for clusters.
      #
      return node, STORAGE_UPDATE_OK if node.last_update_status == STORAGE_UPDATE_OK

      prior_status = node.last_update_status
      node.obj        = obj
      node.agent        = @agent
      node.zone_id      = @agent.zone_id
      # add node to agent's top_managed_elements list
      node.agent_top_id   = @agent.id if topMe
      node.last_update_status = STORAGE_UPDATE_OK
      node.save

      return node, prior_status
    end

    def getAssociatedMetrics(meteredObj, propList=nil)
      sd = @conn.Associators(meteredObj,  :AssocClass   => 'CIM_ElementStatisticalData',
                        :ResultClass  => 'CIM_BlockStorageStatisticalData',
                        :Role     => "ManagedElement",
                        :ResultRole   => "Stats"
      )
      sd.first
    end

    def method_missing(sym, *args)
      from = caller.first
      $log.info "SmisClient.#{sym}: called from #{from}" if $log
      @@serverCalls[sym] += 1
      rv = @conn.send(sym, *args)
      $log.info "SmisClient.#{sym}: returned from #{from}" if $log
      return rv
    end

    def traverseProfile(prof, node, level=0)
      objName = node.obj_name
      prof = [ prof ] unless prof.kind_of?(Array)

      prof.each do |p|
        associations = p[:association]
        associations = [ associations ] unless associations.kind_of?(Array)

        associations.each do |a|
          #
          # We dup "a" because the Associators call will modify it.
          #
          assoc = Associators(objName, a.dup)
          assoc.each do |ao|
            cn, ignore = newNode(ao)
            node.addAssociation(cn, a)
            traverseProfile(p[:next], cn, level+1) if p[:next]
            traverseProfile(p, cn, level+1) if p[:flags][:recurse]
          end
        end
      end
    end

    def checkProfile(prof)
      prof = [ prof ] unless prof.kind_of?(Array)

      prof.each do |p|
        @@pruneUnless << p[:flags][:pruneUnless] if p[:flags][:pruneUnless]
        checkProfile(p[:next]) if p[:next]
      end

      @@pruneUnless.uniq!
    end

    def classHier(className)
      return [] if !className
      return [ className ] if className['MIQ']
      if (hp = @@classHierHash[className])
        return hp
      end
      klass = GetClass(className, :PropertyList => ["superclass"])
      hp = classHier(klass.superclass).dup.unshift(className.to_s)
      @@classHierHash[className] = hp
      return hp
    end

    def self.dumpClasses
      puts
      @@classTable.each do |cn, ch|
        puts "#{cn}, keys: #{ch[:keyProps].join(', ')}"
        ch[:classObj].properties.each do |pn, pv|
          puts "\t#{pn}"
          pv.qualifiers.each { |qn, qv| puts "\t\t#{qn} => #{qv.value.inspect}"}
        end
        puts
      end
    end

    def dumpInstancesByName(instanceNames, level=0, io=$stdout)
      return if !instanceNames
      instanceNames.each do |i|
        indentedPrint(i, level)
        dumpInstanceByName(i, level, io)
      end
    end

    def dumpInstanceByName(instanceName, level=0, io=$stdout)
      i = GetInstance(instanceName, :LocalNamespacePath => instanceName.namespace)
      dumpInstance(i, level, io)
    end

    def dumpInstances(instance, level=0, io=$stdout)
      return if !instance
      instance.each do |i|
        dumpInstance(i, level, io)
      end
    end

    def dumpInstance(instance, level=0, io=$stdout)
      hier = classHier(instance.classname).join(' < ' )
      indentedPrint(hier, level, io)
      instance.properties.each do |k, v|
        unless v.value.kind_of?(Array)
          indentedPrint("  #{k} => #{v.value} (#{v.value.class})", level, io)
        else
          indentedPrint("  #{k} =>", level, io)
          v.value.each { |val| indentedPrint("          #{val}", level, io) }
        end
      end
    end

    def indentedPrint(s, i, io=$stdout)
          io.print @@globalIndent + "  " * i
          io.puts s
    end

    def dumpSnapshots(n)
      n.findEach do |node|
        puts node.objName.classname
        si = Associators(node.objName,  :AssocClass   => 'ONTAP_SnapshotBasedOnFlexVol',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
        )
        if !si.empty?
          dumpInstances(si, 2)
          next
        end
        si = Associators(node.objName,  :AssocClass   => 'ONTAP_SnapshotBasedOnExtent',
                        :ResultClass  => 'ONTAP_Snapshot',
                        :Role     => "Antecedent",
                        :ResultRole   => "Dependent"
        )
        dumpInstances(si, 2) if !si.empty?
      end
    end

    def getVimSmis(server, username, password)
      MiqVimSmis.new(self, server, username, password)
    end

  end # class SmisClient

  class SmisMetricManager
    RATE_STATS = [
      'KBytesRead',     'k_bytes_read',
        'ReadIOs',        'read_ios',
        'KBytesWritten',    'k_bytes_written',
        'KBytesTransferred',  'k_bytes_transferred',
        'WriteIOs',       'write_ios',
        'WriteHitIOs',      'write_hit_ios',
        'ReadHitIOs',     'read_hit_ios',
        'TotalIOs',       'total_ios'
    ]

    @@meToMetricManager = {}

    def initialize(sysNode, client)
      @nmetric    = 5
      @sysNode  = sysNode
      @client   = client

      #
      # Get the BlockStatisticsService for the array.
      #
      blockStatSvc = @client.AssociatorNames(sysNode.obj_name,  :AssocClass   => 'CIM_HostedService',
                                    :ResultClass  => 'CIM_BlockStatisticsService',
                                    :Role     => "Antecedent",
                                    :ResultRole   => "Dependent").first

      blockStatCap = @client.Associators(blockStatSvc,      :AssocClass   => 'CIM_ElementCapabilities',
                                    :ResultClass  => 'CIM_BlockStatisticsCapabilities',
                                    :Role     => "ManagedElement",
                                    :ResultRole   => "Capabilities").first

      @clockTickInterval  = blockStatCap['ClockTickInterval'].value
      @ticksPerSec    = 1000000.0 / @clockTickInterval
      @secsPerTick    = 1.0 / @ticksPerSec

      @@meToMetricManager[sysNode.obj_name_str] = self
    end

    def self.metricManager(sysNode)
      @@meToMetricManager[sysNode.obj_name_str]
    end

    def updateState
    end

    def updateMetrics
      @sysNode.elements_with_metrics.each do |metricInstance|
        curMetricObj = @client.getAssociatedMetrics(metricInstance.obj_name)
        unless curMetricObj
          $log.warn "SmisMetricManager.updateMetrics: Could not retrieve metrics for #{metricInstance.obj_name}"
          next
        end

        metricEntry = metricInstance.metrics
        lastMetricObj = metricEntry.metric_obj

        #
        # Compute the time delta in seconds.
        #
        # NOTE: Currently wbem/com_obj.rb will always return Time objects.
        #
        dtDelta = curMetricObj['StatisticTime'] - lastMetricObj['StatisticTime']
        if dtDelta.kind_of?(Rational) # delta DateTime
          h, m, s, ign = Date::day_fraction_to_time(dtDelta)
          deltaSecs = h * 60 * 60 + m * 60 + s
        else  # delta Time
          deltaSecs = dtDelta
        end
        deltaTicks = deltaSecs * @ticksPerSec

        if deltaSecs <= 0.0
          name = metricInstance.evm_display_name
          zn = (deltaSecs == 0 ? "zero" : "negative")
          $log.warn "SmisMetricManager.updateMetrics: #{zn} Delta Time for (#{metricInstance.class}, #{metricInstance.id}, #{name})"
          next
        end

        #
        # Calculate derived metrics.
        #
        derivedMetrics = MiqCimDerivedMetric.new
        derivedMetrics.statistic_time = curMetricObj['StatisticTime']
        derivedMetrics.interval = deltaSecs

        delta = {}
        RATE_STATS.each_slice(2) do |sn, tsn|
          next if curMetricObj[sn].nil?
          delta[sn] = curMetricObj[sn].value - lastMetricObj[sn].value  # for later
          derivedMetrics[tsn + '_per_sec'] = delta[sn].to_f / deltaSecs
        end

        #
        # Compute % Utilization; the optional IdleTimeCounter is required to do this.
        #
        if curMetricObj['IdleTimeCounter']
          deltaIdleTime = curMetricObj['IdleTimeCounter'].value - lastMetricObj['IdleTimeCounter'].value
          derivedMetrics.utilization = (deltaTicks.to_f - deltaIdleTime.to_f) / deltaTicks * 100
        end

        #
        # The optional IOTimeCounter is needed to compute a number of derived metrics.
        # If IOTimeCounter is not available, but IdleTimeCounter is we derive
        #       deltaIOTime = deltaTicks - deltaIdleTime
        # This assumes that when the object is not idle, it is doing IO. I'm not sure
        # if this is valid in all cases.
        #
        deltaIOTime = nil
        if curMetricObj['IOTimeCounter']
          deltaIOTime = curMetricObj['IOTimeCounter'].value - lastMetricObj['IOTimeCounter'].value
        elsif curMetricObj['IdleTimeCounter']
          deltaIOTime = deltaTicks - deltaIdleTime
        end

        #
        # Compute derived metrics that are based on IOTime.
        #
        if deltaIOTime
          #
          # Response time in seconds.
          #
          if (d = delta['TotalIOs']) != 0
            derivedMetrics.response_time_sec = (deltaIOTime.to_f * @secsPerTick) / d
          else
            derivedMetrics.response_time_sec = 0.0
          end
          #
          # Queue depth
          #
          derivedMetrics.queue_depth = derivedMetrics.total_ios_per_sec * derivedMetrics.response_time_sec

          if (u = derivedMetrics.utilization)
            if (d = derivedMetrics.total_ios_per_sec) != 0.0
              derivedMetrics.service_time_sec = (u * 0.01) / d
            else
              derivedMetrics.service_time_sec = 0.0
            end
            derivedMetrics.wait_time_sec = derivedMetrics.response_time_sec - derivedMetrics.service_time_sec
          end
        end

        if (d = delta['ReadIOs']) != 0 && (n = delta['KBytesRead'])
          derivedMetrics.avg_read_size    = n.to_f / d
        else
          derivedMetrics.avg_read_size  = 0.0
        end

        if (d = delta['WriteIOs']) != 0 && (n = delta['KBytesWritten'])
          derivedMetrics.avg_write_size = n.to_f / d
        else
          derivedMetrics.avg_write_size = 0.0
        end

        #
        # XXX ??? TotalIOs != ReadIOs + WriteIOs
        #
        if (d = delta['TotalIOs']) && d != 0
          derivedMetrics.pct_read   = (delta['ReadIOs'].to_f / d) * 100               if delta['ReadIOs']
          derivedMetrics.pct_write  = (delta['WriteIOs'].to_f / d) * 100              if delta['WriteIOs']
          derivedMetrics.pct_hit    = ((delta['ReadHitIOs'] + d).to_f / delta['TotalIOs']) * 100  if delta['ReadHitIOs']
        else
          derivedMetrics.pct_read   = 0.0
          derivedMetrics.pct_write    = 0.0
          derivedMetrics.pct_hit    = 0.0
        end

        metricEntry.miq_derived_metrics.first.destroy if metricEntry.miq_derived_metrics.length == @nmetric
        metricEntry.miq_derived_metrics << derivedMetrics
        metricEntry.metric_obj = curMetricObj
        metricEntry.save
      end
    end

  end # class SmisMetrics

  class SmisDot

    def self.dotInit
    end

    def self.dotStart(io=$stdout, rankDir='TB')
      io.puts "digraph G {"
      io.puts "\tsize = \"22,22\";"
      io.puts "\toverlap = false;"
      io.puts "\tsplines = true;"
      io.puts "\trankdir = #{rankDir};"
    end

    def self.dotDump(node, prof, flags=nil, depth=nil, io=$stdout)
      dotConnections  = {}
      dotClusters   = []
      @dotNodeHash  = {}
      dotConnect(node, prof, flags, depth, dotConnections, dotClusters)
      @clusterIdx = 0
      dumpDotClusters(io, dotClusters)

      dotConnections.each_key { |k| io.puts k + ";" }
    end

    def self.dotEnd(io=$stdout)
      io.puts "}"
    end

    def self.dotConnect(node, prof, flags, depth, connHash, cluster, level=1, antecedent=nil)
      return if depth && depth < level

      objName = node.obj_name_str
      curCluster = cluster
      unless @dotNodeHash[objName]
        @dotNodeHash[objName] = node
        if node.kinda?('CIM_CompositeExtent')
          curCluster = []
          cluster << curCluster
        end
        curCluster << node
      end
      return if depth && depth < level + 1

      prof = [ prof ] unless prof.kind_of?(Array)
      prof.each do |p|
        if (puk = p[:flags][:pruneUnless]) && flags
          next unless flags[puk] == 'true'
        end
        associations = p[:association]
        associations = [ associations ] unless associations.kind_of?(Array)

        associations.each do |a|
          node.getAssociators(a).each do |an|
            next  if antecedent && an.obj_name_str == antecedent.obj_name_str
            unless @dotNodeHash[an.obj_name_str]
              @dotNodeHash[an.obj_name_str] = an
              if node.kinda?('CIM_CompositeExtent')
                curCluster = []
                cluster << curCluster
              end
              curCluster << an
            end

            if p[:flags][:reverse]
              conn = "\t#{dotNodeName(an)} -> #{dotNodeName(node)}"
              rconn = "\t#{dotNodeName(node)} -> #{dotNodeName(an)}"
            else
              conn = "\t#{dotNodeName(node)} -> #{dotNodeName(an)}"
              rconn = "\t#{dotNodeName(an)} -> #{dotNodeName(node)}"
            end
            connHash[conn] = true unless connHash[rconn]

            nextLevel = p[:flags][:set_level] || level + 1

            dotConnect(an, p[:next],  flags, depth, connHash, curCluster, nextLevel, node)  if p[:next]
            dotConnect(an, p,     flags, depth, connHash, curCluster, nextLevel, node)  if p[:flags][:recurse]
          end
        end
      end
    end

    def self.dotNodeInfo(node)
      obj = node.obj
      return 'invhouse',    obj['OtherIdentifyingInfo'][0]                if node.kinda?('CIM_ComputerSystem')
      return 'folder',    obj['InstanceID'].sub(/[^:]*:[^:]*:/,"").sub(':(','\n(')  if node.kinda?('SNIA_FileShare')
      return 'tab',     obj['FileSystemType']+':'+obj['Root']           if node.kinda?('SNIA_LocalFileSystem')
      return 'ellipse',   obj['name']                         if node.kinda?('CIM_LogicalDisk')
      return 'doubleoctagon', obj['name']                         if node.kinda?('CIM_CompositeExtent')
      return 'octagon',   obj['name']                         if node.kinda?('ONTAP_FlexVolExtent')
      return 'ellipse',   obj['DeviceID']                       if node.kinda?('CIM_StorageExtent')
      return 'component',   obj['DeviceID']+':'+obj['PermanentAddress']         if node.kinda?('CIM_LogicalPort')
      return 'note',      obj['Caption']                        if node.kinda?('SNIA_ExportedFileShareSetting')
      return 'note',      obj['ElementName']                      if node.kinda?('CIM_FileSystemSetting')
      return 'note',      obj['ElementName']                      if node.kinda?('CIM_StorageSetting')

      return 'house',     obj['name']                         if node.class_name == 'MIQ_CimHostSystem'
      return 'egg',     obj['name']                         if node.class_name == 'MIQ_CimVirtualMachine'
      return 'ellipse',   obj['name']                         if node.class_name == 'MIQ_CimVirtualDisk'
      return 'box',     obj['name']                         if node.class_name == 'MIQ_CimDatastore'

      return 'ellipse',   obj['name']
    end

    def self.dotHealth(node)
      return 'springgreen3' # XXX
      st = node.metrics.miq_derived_metrics.last

      return 'springgreen3' unless st
      return 'springgreen3' unless (u = st.utilization)
      return 'red'      if u > 75.0
      return 'yellow'     if u > 45.0
      return 'springgreen3'
    end

    def self.dumpDotClusters(io, clusters, level=1)
      clusters.each do |c|
        if c.kind_of?(Array)
          shape, id = dotNodeInfo(c.first)
          io.puts "    " * level + "subgraph cluster_#{@clusterIdx} {"
          @clusterIdx += 1
          dumpDotClusters(io, c, level+1)
          io.puts "    " * level + "}"
        else
          shape, id = dotNodeInfo(c)
          color = ""
          color = "color=#{dotHealth(c)},style=filled," if c.metric_id
          nodeDef = %Q{#{dotNodeName(c)} [shape=#{shape},#{color}label="#{c.class_name}\\n#{id}"} + %Q{,URL="#"];}
          io.puts "    " * level + nodeDef
          # Rails.logger.info("GV: #{nodeDef}")
        end
      end
    end

    def self.dotNodeName(node)
      return "#{node.class_name}_#{node.id}"
    end

  end # class SmisDot

end # module MiqSmisClient
