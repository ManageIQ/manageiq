require 'date'

class MiqVimPerfHistory
	
	attr_reader :invObj

    def initialize(invObj)
		@invObj			= invObj
		@sic			= invObj.sic
		@perfManager	= @sic.perfManager
    end
    
    #
    # Interval processing
    #

	def intervals
		if @intervals.nil?
			@intervals = @invObj.getMoProp(@perfManager, "historicalInterval")["historicalInterval"]
			@intervals = @intervals["PerfInterval"] if @intervals.kind_of?(Hash)
		end
		return @intervals
	end

	def intervalMap
		if @intervalMap.nil?
			# Hash interval information by [name] and interval ID (samplingPeriod)
			@intervalMap = Hash.new
			intervals.each do |i|
				@intervalMap[i['name']] = i
				# i['samplingPeriod'] = i['samplingPeriod'].to_i
				i['length'] = i['length'].to_i
				@intervalMap[i['samplingPeriod']] = i
				@intervalMap[i['samplingPeriod'].to_i] = i
			end
		end
		return @intervalMap
	end

    #
    # Counter processing
    #

	def perfCounterInfo
		if @perfCounterInfo.nil?
			@perfCounterInfo = @invObj.getMoProp(@perfManager, "perfCounter")['perfCounter']
			@perfCounterInfo = @perfCounterInfo['PerfCounterInfo'] if @perfCounterInfo.kind_of?(Hash)

			#
			# Hash counter information by [group][name] and [counter ID].
			# Also, hash counter group info by group key.
			#
			@cInfoMap   = Hash.new  # Counter info hashed by [group][name]
			@id2Counter = Hash.new  # Counter info hashed by [id]
			@groupInfo  = Hash.new  # Description of counter groups, hashed by group key
			@perfCounterInfo.each do |pci|
				# pci['key'] = pci['key'].to_i
				@id2Counter[pci['key']] = pci
				ginfo = pci['groupInfo']
				@groupInfo[ginfo['key']] = ginfo
				group = ginfo['key']
				@cInfoMap[group] = Hash.new if !@cInfoMap[group]
				name = pci['nameInfo']['key']
				@cInfoMap[group][name] = Array.new if !@cInfoMap[group][name]
				@cInfoMap[group][name] << pci
			end if @perfCounterInfo
		end
		return @perfCounterInfo
	end

	def cInfoMap
		perfCounterInfo if @cInfoMap.nil?
		return @cInfoMap
	end

	def id2Counter
		perfCounterInfo if @id2Counter.nil?
		return @id2Counter
	end

	def groupInfo
		perfCounterInfo if @groupInfo.nil?
		return @groupInfo
	end

    def getCounterInfo(group, name, rollupType, statsType=nil)
        raise "getCounterInfo: counter group #{group}, not found" if !(nh = cInfoMap[group])
        raise "getCounterInfo: counter #{group}.#{name}, not found" if !(ca = nh[name])
        
        ca.each do |ci|
            next if ci['rollupType'] != rollupType
            next if statsType && ci['statsType'] != statsType
            return ci
        end
        raise "getCounterInfo: counter #{group}.#{name}, no counter matching rollupType and statsType"
    end
    
    def queryProviderSummary(mor)
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryProviderSummary: calling queryPerfProviderSummary" if $vim_log
        psum = @invObj.queryPerfProviderSummary(@perfManager, mor)
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryProviderSummary: returned from queryPerfProviderSummary" if $vim_log
        return(psum)
    end
    
    def availMetricsForEntity(mor, *aa)
        if aa.length > 0
            ah = aa[0]
            intervalId = ah[:intervalId]	|| nil
            beginTime  = ah[:beginTime]		|| nil
            endTime    = ah[:endTime]		|| nil
        end
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).availMetricsForEntity: calling queryAvailablePerfMetric" if $vim_log
        pmids = @invObj.queryAvailablePerfMetric(@perfManager, mor, beginTime, endTime, intervalId)
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).availMetricsForEntity: returned from queryAvailablePerfMetric" if $vim_log
        return(pmids)
    end

    #
    # Query an single metric from a single entity.
    #
    def queryPerf(entnty, ah)
        ah[:entity]     = entnty
        pqs             = getPerfQuerySpec(ah)
        
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerf: calling queryPerf" if $vim_log
        umPem = @invObj.queryPerf(@perfManager, pqs)[0]
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerf: returned from queryPerf" if $vim_log

        #
        # Construct an array of (timestamp, value) pairs.
        #
        ra = Array.new
        return(ra) if !umPem || !umPem.xsiType
        return(ra) if !umPem.has_key?('value')
		return(ra) if umPem['value'].kind_of?(Hash) && !umPem['value'].has_key?('value')
        return(ra) if !umPem.has_key?('sampleInfo')
        
        va = umPem['value']
		va = va[0] if va.kind_of?(Array)
		va = va['value']
        umPem['sampleInfo'] = [ umPem['sampleInfo'] ] if !umPem['sampleInfo'].kind_of?(Array)
        umPem['sampleInfo'].each_index do |i|
            si = umPem['sampleInfo'][i]
            ra << DateTime.parse(si['timestamp'])
            ra << va[i].to_i
        end
        return(ra)
    end
    
    def queryPerfMulti(aa)
        querySpec = VimArray.new('ArrayOfPerfQuerySpec') do |pqsa|
			aa.each { |ah| pqsa << getPerfQuerySpec(ah) }
		end
        
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerfMulti: calling queryPerf" if $vim_log
        pema = @invObj.queryPerf(@perfManager, querySpec)
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerfMulti: returned from queryPerf" if $vim_log
        
        return(nil) if !pema
        
        pema = [ pema ] if !pema.kind_of? Array
        pema.each { |pem| perfEntityMetricFixup(pem) }
        return(pema)
    end
    
    def queryPerfComposite(entnty, ah)
        ah[:entity]     = entnty
        pqs             = getPerfQuerySpec(ah)
        
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerfComposite: calling queryPerfComposite" if $vim_log
        umPem = @invObj.queryPerfComposite(@perfManager, pqs)
		$vim_log.info "MiqVimPerfHistory(#{@invObj.server}, #{@invObj.username}).queryPerfComposite: returned from queryPerfComposite" if $vim_log
        
        perfEntityMetricFixup(umPem['entity'])
        umPem['childEntity'] = [ umPem['childEntity'] ] if umPem['childEntity'].kind_of? Hash
        umPem['childEntity'].each { |ce| perfEntityMetricFixup(ce) } if umPem['childEntity']
        
        return(umPem)
    end
    
    def release
	    # @invObj.releaseObj(self)
    end
    
    private
    
    def getPerfQuerySpec(ah)
        raise "getPerfQuerySpec: intervalId not specified" if !ah[:intervalId]
        raise "getPerfQuerySpec: counterId not specified"  if !ah[:counterId] && !ah[:metricId]
        
		pqSpec = VimHash.new('PerfQuerySpec') do |pqs|
			pqs.entity      = ah[:entity]			if ah[:entity]
			pqs.intervalId  = ah[:intervalId]
	        pqs.format      = PerfFormat::Normal

	        pqs.endTime     = ah[:endTime].to_s		if ah[:endTime]
	        pqs.startTime   = ah[:startTime].to_s	if ah[:startTime]
	        pqs.maxSample   = ah[:maxSample]		if ah[:maxSample]
	
			pqs.metricId    = VimArray.new('ArrayOfPerfMetricId') do |pmia|
				if ah[:counterId]
					ids = [ ah ]
				else
					ids = ah[:metricId]
				end
	            ids.each do |midh|
	                pmia << VimHash.new('PerfMetricId') do |pmi|
						pmi.counterId   = midh[:counterId]
		                pmi.instance    = midh[:instance] || ""
					end
	            end
			end
		end

        return(pqSpec)
    end
    
    def perfEntityMetricFixup(pemHash)
        return
        pemHash["sampleInfo"] = [ pemHash["sampleInfo"] ] if pemHash["sampleInfo"].kind_of? Hash
        
        pemHash["sampleInfo"].each do |si|
            si["interval"] = si["interval"].to_i if si["interval"]
            si['timestamp'] = DateTime.parse(si['timestamp'])
        end if pemHash["sampleInfo"]
        
        pemHash["value"] = [ pemHash["value"] ] if pemHash["value"].kind_of? Hash
        
        pemHash["value"].each do |pms|
            pms["value"] = [ pms["value"] ] if !pms["value"].kind_of? Array
            
            pms["value"].each_index do |i|
                pms["value"][i] = pms["value"][i].to_i
            end
        end if pemHash["value"]
    end
    
end # class MiqVimPerfHistory
