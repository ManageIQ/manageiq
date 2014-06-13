
$:.push(File.dirname(__FILE__))

require "handsoap"
require "VimTypes"

class VimService < Handsoap::Service
	
	attr_reader :sic, :about, :apiVersion, :isVirtualCenter, :v20, :v2, :v4, :serviceInstanceMor
		
	Handsoap.http_driver = :HTTPClient
		
	def initialize(ep)
		super
				
		setNameSpace('urn:vim2')
		
		@serviceInstanceMor = VimString.new("ServiceInstance", "ServiceInstance")
		
		begin
			@sic = retrieveServiceContent
		rescue Handsoap::Fault
			setNameSpace('urn:vim25')
			@sic = retrieveServiceContent
		end
		
		@about				= @sic.about
		@apiVersion         = @about.apiVersion
		@v20				= @apiVersion =~ /2\.0\..*/
		@v2					= @apiVersion =~ /2\..*/
		@v4					= @apiVersion =~ /4\..*/
		@isVirtualCenter    = @about.apiType == "VirtualCenter"
		
		setNameSpace('urn:vim25') unless @v20
	end
	
	def acquireCloneTicket(sm)
		response = invoke("n1:AcquireCloneTicket") do |message|
			message.add "n1:_this", sm do |i|
				i.set_attr "type", sm.vimType
			end
		end
		return(parse_response(response, 'AcquireCloneTicketResponse')['returnval'])
	end

	def acquireMksTicket(mor)
		response = invoke("n1:AcquireMksTicket") do |message|
			message.add "n1:_this", mor do |i|
				i.set_attr "type", mor.vimType
			end
		end
		return(parse_response(response, 'AcquireMksTicketResponse')['returnval'])
	end
	
	def addHost_Task(clustMor, spec, asConnected, resourcePool=nil, license=nil)
		response = invoke("n1:AddHost_Task") do |message|
			message.add "n1:_this", clustMor do |i|
				i.set_attr "type", clustMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", spec.xsiType
				marshalObj(i, spec)
			end
			message.add "n1:asConnected", asConnected
			message.add "n1:resourcePool", resourcePool do |i|
				i.set_attr "type", resourcePool.vimType
			end unless resourcePool.nil?
			message.add "n1:license", license unless license.nil?
		end
		return(parse_response(response, 'AddHost_TaskResponse')['returnval'])
	end
	
	def addInternetScsiSendTargets(hssMor, iScsiHbaDevice, targets)
		response = invoke("n1:AddInternetScsiSendTargets") do |message|
			message.add "n1:_this", hssMor do |i|
				i.set_attr "type", hssMor.vimType
			end
			message.add "n1:iScsiHbaDevice", iScsiHbaDevice
			if targets.kind_of?(Array)
				targets.each do |t|
					message.add "n1:targets" do |i|
						i.set_attr "xsi:type", t.xsiType
						marshalObj(i, t)
					end
				end
			else
				message.add "n1:targets" do |i|
					i.set_attr "xsi:type", targets.xsiType
					marshalObj(i, targets)
				end
			end
		end
		return(parse_response(response, 'AddInternetScsiSendTargetsResponse'))
	end
	
	def addInternetScsiStaticTargets(hssMor, iScsiHbaDevice, targets)
		response = invoke("n1:AddInternetScsiStaticTargets") do |message|
			message.add "n1:_this", hssMor do |i|
				i.set_attr "type", hssMor.vimType
			end
			message.add "n1:iScsiHbaDevice", iScsiHbaDevice
			if targets.kind_of?(Array)
				targets.each do |t|
					message.add "n1:targets" do |i|
						i.set_attr "xsi:type", t.xsiType
						marshalObj(i, t)
					end
				end
			else
				message.add "n1:targets" do |i|
					i.set_attr "xsi:type", targets.xsiType
					marshalObj(i, targets)
				end
			end
		end
		return(parse_response(response, 'AddInternetScsiStaticTargetsResponse'))
	end
	
	def addStandaloneHost_Task(folderMor, spec, addConnected, license=nil)
		response = invoke("n1:AddStandaloneHost_Task") do |message|
			message.add "n1:_this", folderMor do |i|
				i.set_attr "type", folderMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", spec.xsiType
				marshalObj(i, spec)
			end
			message.add "n1:addConnected", addConnected
			message.add "n1:license", license unless license.nil?
		end
		return(parse_response(response, 'AddStandaloneHost_TaskResponse')['returnval'])
	end
	
	def browseDiagnosticLog(diagnosticManager, host, key, start, lines)
		response = invoke("n1:BrowseDiagnosticLog") do |message|
			message.add "n1:_this", diagnosticManager do |i|
				i.set_attr "type", diagnosticManager.vimType
			end
			message.add "n1:host", host do |i|
				i.set_attr "type", host.vimType
			end if host
			message.add "n1:key", key
			message.add "n1:start", start if start
			message.add "n1:lines", lines if lines
		end
		return(parse_response(response, 'BrowseDiagnosticLogResponse')['returnval'])
	end
	
	def cancelTask(tmor)
		response = invoke("n1:CancelTask") do |message|
			message.add "n1:_this", tmor do |i|
				i.set_attr "type", tmor.vimType
			end
		end
		return(parse_response(response, 'CancelTaskResponse'))
	end
	
	def cancelWaitForUpdates(propCol)
		response = invoke("n1:CancelWaitForUpdates") do |message|
			message.add "n1:_this", propCol do |i|
				i.set_attr "type", propCol.vimType
			end
		end
		return(parse_response(response, 'CancelWaitForUpdatesResponse'))
	end
	
	def cloneVM_Task(vmMor, fmor, name, cspec)
		response = invoke("n1:CloneVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:folder", fmor do |i|
				i.set_attr "type", fmor.vimType
			end
			message.add "n1:name", name
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", cspec.xsiType
				marshalObj(i, cspec)
			end
		end		
		return(parse_response(response, 'CloneVM_TaskResponse')['returnval'])
	end
	
	def createAlarm(alarmManager, mor, aSpec)
		response = invoke("n1:CreateAlarm") do |message|
			message.add "n1:_this", alarmManager do |i|
				i.set_attr "type", alarmManager.vimType
			end
			message.add "n1:entity", mor do |i|
				i.set_attr "type", mor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", aSpec.xsiType
				marshalObj(i, aSpec)
			end
		end
		return(parse_response(response, 'CreateAlarmResponse')['returnval'])
	end
	
	def createCollectorForEvents(eventManager, eventFilterSpec)
		response = invoke("n1:CreateCollectorForEvents") do |message|
			message.add "n1:_this", eventManager do |i|
				i.set_attr "type", eventManager.vimType
			end
			message.add "n1:filter" do |i|
				i.set_attr "xsi:type", eventFilterSpec.xsiType
				marshalObj(i, eventFilterSpec)
			end
		end
		return(parse_response(response, 'CreateCollectorForEventsResponse')['returnval'])
	end
	
	def createCustomizationSpec(csmMor, item)
		response = invoke("n1:CreateCustomizationSpec") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:item" do |i|
				i.set_attr "xsi:type", item.xsiType
				marshalObj(i, item)
			end
		end
		return(parse_response(response, 'CreateCustomizationSpecResponse')['returnval'])
	end
	
	def createFilter(propCol, pfSpec, partialUpdates)
		response = invoke("n1:CreateFilter") do |message|
			message.add "n1:_this", propCol do |i|
				i.set_attr "type", propCol.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", pfSpec.xsiType
				marshalObj(i, pfSpec)
			end
			message.add "n1:partialUpdates", partialUpdates
		end
		return(parse_response(response, 'CreateFilterResponse')['returnval'])
	end
	
	def createNasDatastore(dssMor, spec)
		response = invoke("n1:CreateNasDatastore") do |message|
			message.add "n1:_this", dssMor do |i|
				i.set_attr "type", dssMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", spec.xsiType
				marshalObj(i, spec)
			end
		end
		return(parse_response(response, 'CreateNasDatastoreResponse')['returnval'])
	end
	
	def createSnapshot_Task(vmMor, name, desc, memory, quiesce)
		response = invoke("n1:CreateSnapshot_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:name", name
			message.add "n1:description", desc	if desc
			message.add "n1:memory", memory.to_s
			message.add "n1:quiesce", quiesce
		end		
		return(parse_response(response, 'CreateSnapshot_TaskResponse')['returnval'])
	end
	
	def currentTime
		response = invoke("n1:CurrentTime") do |message|
			message.add "n1:_this", "ServiceInstance" do |i|
				i.set_attr "type", "ServiceInstance"
			end
		end
		return(parse_response(response, 'CurrentTimeResponse')['returnval'])
	end
	
	def customizationSpecItemToXml(csmMor, item)
		response = invoke("n1:CustomizationSpecItemToXml") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:item" do |i|
				i.set_attr "xsi:type", item.xsiType
				marshalObj(i, item)
			end
		end
		return(parse_response(response, 'CustomizationSpecItemToXmlResponse')['returnval'])
	end
	
	def deleteCustomizationSpec(csmMor, name)
		response = invoke("n1:DeleteCustomizationSpec") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:name", name
		end
		return(parse_response(response, 'DeleteCustomizationSpecResponse'))['returnval']
	end
	
	def deselectVnicForNicType(vnmMor, nicType, device)
		response = invoke("n1:DeselectVnicForNicType") do |message|
			message.add "n1:_this", vnmMor do |i|
				i.set_attr "type", vnmMor.vimType
			end
			message.add "n1:nicType", nicType
			message.add "n1:device", device
		end
		return(parse_response(response, 'DeselectVnicForNicTypeResponse'))
	end
	
	def destroy_Task(mor)
		response = invoke("n1:Destroy_Task") do |message|
			message.add "n1:_this", mor do |i|
				i.set_attr "type", mor.vimType
			end
		end
		return(parse_response(response, 'Destroy_TaskResponse')['returnval'])
	end
	
	def destroyCollector(collectorMor)
		response = invoke("n1:DestroyCollector") do |message|
			message.add "n1:_this", collectorMor do |i|
				i.set_attr "type", collectorMor.vimType
			end
		end
		return(parse_response(response, 'DestroyCollectorResponse'))
	end
	
	def destroyPropertyFilter(filterSpecRef)
		response = invoke("n1:DestroyPropertyFilter") do |message|
			message.add "n1:_this", filterSpecRef do |i|
				i.set_attr "type", filterSpecRef.vimType
			end
		end
		return(parse_response(response, 'DestroyPropertyFilterResponse'))
	end
	
	def disableRuleset(fwsMor, rskey)
		response = invoke("n1:DisableRuleset") do |message|
			message.add "n1:_this", fwsMor do |i|
				i.set_attr "type", fwsMor.vimType
			end
			message.add "n1:id", rskey
		end
		return(parse_response(response, 'DisableRulesetResponse'))
	end
	
	def doesCustomizationSpecExist(csmMor, name)
		response = invoke("n1:DoesCustomizationSpecExist") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:name", name
		end
		return(parse_response(response, 'DoesCustomizationSpecExistResponse'))['returnval']
	end
	
	def enableRuleset(fwsMor, rskey)
		response = invoke("n1:EnableRuleset") do |message|
			message.add "n1:_this", fwsMor do |i|
				i.set_attr "type", fwsMor.vimType
			end
			message.add "n1:id", rskey
		end
		return(parse_response(response, 'EnableRulesetResponse'))
	end
	
	def enterMaintenanceMode_Task(hMor, timeout=0, evacuatePoweredOffVms=false)
		response = invoke("n1:EnterMaintenanceMode_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:timeout", timeout.to_s
			message.add "n1:evacuatePoweredOffVms", evacuatePoweredOffVms.to_s
		end
		return(parse_response(response, 'EnterMaintenanceMode_TaskResponse'))['returnval']
	end
	
	def exitMaintenanceMode_Task(hMor, timeout=0)
		response = invoke("n1:ExitMaintenanceMode_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:timeout", timeout.to_s
		end
		return(parse_response(response, 'ExitMaintenanceMode_TaskResponse'))['returnval']
	end
	
	def getAlarm(alarmManager, mor)
		response = invoke("n1:GetAlarm") do |message|
			message.add "n1:_this", alarmManager do |i|
				i.set_attr "type", alarmManager.vimType
			end
			message.add "n1:entity", mor do |i|
				i.set_attr "type", mor.vimType
			end if mor
		end
		return(parse_response(response, 'GetAlarmResponse')['returnval'])
	end
	
	def getCustomizationSpec(csmMor, name)
		response = invoke("n1:GetCustomizationSpec") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:name", name
		end
		return(parse_response(response, 'GetCustomizationSpecResponse'))['returnval']
	end
	
	def login(sessionManager, username, password)
		response = invoke("n1:Login") do |message|
			message.add "n1:_this", sessionManager do |i|
				i.set_attr "type", "SessionManager"
			end
			message.add "n1:userName", username
			message.add "n1:password", password
		end
		return(parse_response(response, 'LoginResponse')['returnval'])
	end
	
	def logout(sessionManager)
		response = invoke("n1:Logout") do |message|
			message.add "n1:_this", sessionManager do |i|
				i.set_attr "type", "SessionManager"
			end
		end
		return(parse_response(response, 'LogoutResponse'))
	end
	
	def logUserEvent(eventManager, entity, msg)
		response = invoke("n1:LogUserEvent") do |message|
			message.add "n1:_this", eventManager do |i|
				i.set_attr "type", eventManager.vimType
			end
			message.add "n1:entity", entity do |i|
				i.set_attr "type", entity.vimType
			end
			message.add "n1:msg", msg
		end
		return(parse_response(response, 'LogUserEventResponse'))
	end
	
	def markAsTemplate(vmMor)
		response = invoke("n1:MarkAsTemplate") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'MarkAsTemplateResponse'))
	end
	
	def markAsVirtualMachine(vmMor, pmor, hmor=nil)
		response = invoke("n1:MarkAsVirtualMachine") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:pool", pmor do |i|
				i.set_attr "type", pmor.vimType
			end
			message.add "n1:host", hmor do |i|
				i.set_attr "type", hmor.vimType
			end if hmor
		end
		return(parse_response(response, 'MarkAsVirtualMachineResponse'))
	end
	
	def migrateVM_Task(vmMor, pmor=nil, hmor=nil, priority="defaultPriority", state=nil)
		response = invoke("n1:MigrateVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:pool", pmor do |i|
				i.set_attr "type", pmor.vimType
			end if pmor
			message.add "n1:host", hmor do |i|
				i.set_attr "type", hmor.vimType
			end if hmor
			message.add "n1:priority", priority
			message.add "n1:state", state if state
		end
		return(parse_response(response, 'MigrateVM_TaskResponse')['returnval'])
	end

	def relocateVM_Task(vmMor, cspec, priority="defaultPriority")
		response = invoke("n1:RelocateVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", cspec.xsiType
				marshalObj(i, cspec)
			end
			message.add "n1:priority", priority
		end
		return(parse_response(response, 'RelocateVM_TaskResponse')['returnval'])
	end

	def powerDownHostToStandBy_Task(hMor, timeoutSec=0, evacuatePoweredOffVms=false)
		response = invoke("n1:PowerDownHostToStandBy_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:timeoutSec", timeoutSec.to_s
			message.add "n1:evacuatePoweredOffVms", evacuatePoweredOffVms.to_s
		end
		return(parse_response(response, 'PowerDownHostToStandBy_TaskResponse'))['returnval']
	end
	
	def powerOffVM_Task(vmMor)
		response = invoke("n1:PowerOffVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'PowerOffVM_TaskResponse')['returnval'])
	end
	
	def powerOnVM_Task(vmMor)
		response = invoke("n1:PowerOnVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'PowerOnVM_TaskResponse')['returnval'])
	end
	
	def powerUpHostFromStandBy_Task(hMor, timeoutSec=0)
		response = invoke("n1:PowerUpHostFromStandBy_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:timeoutSec", timeoutSec.to_s
		end
		return(parse_response(response, 'PowerUpHostFromStandBy_TaskResponse'))['returnval']
	end
	
	def queryAvailablePerfMetric(perfManager, entity, beginTime=nil, endTime=nil, intervalId=nil)
		response = invoke("n1:QueryAvailablePerfMetric") do |message|
			message.add "n1:_this", perfManager do |i|
				i.set_attr "type", perfManager.vimType
			end
			message.add "n1:entity", entity do |i|
				i.set_attr "type", entity.vimType
			end
			message.add "n1:beginTime", beginTime.to_s	if beginTime
			message.add "n1:endTime", endTime.to_s		if endTime
			message.add "n1:intervalId", intervalId		if intervalId
		end
		return(parse_response(response, 'QueryAvailablePerfMetricResponse')['returnval'])
	end
	
	def queryDescriptions(diagnosticManager, entity)
		response = invoke("n1:QueryDescriptions") do |message|
			message.add "n1:_this", diagnosticManager do |i|
				i.set_attr "type", diagnosticManager.vimType
			end
			message.add "n1:host", entity do |i|
				i.set_attr "type", entity.vimType
			end if entity
		end
		return(parse_response(response, 'QueryDescriptionsResponse')['returnval'])
	end
	
	def queryDvsConfigTarget(dvsManager, hmor, dvs)
		response = invoke("n1:QueryDvsConfigTarget") do |message|
			message.add "n1:_this", dvsManager do |i|
				i.set_attr "type", dvsManager.vimType
			end
			message.add "n1:host", hmor do |i|
				i.set_attr "type", hmor.vimType
			end if hmor
		end
		return(parse_response(response, 'QueryDvsConfigTargetResponse')['returnval'])
		# TODO dvs
	end
	
	def queryNetConfig(vnmMor, nicType)
		response = invoke("n1:QueryNetConfig") do |message|
			message.add "n1:_this", vnmMor do |i|
				i.set_attr "type", vnmMor.vimType
			end
			message.add "n1:nicType", nicType
		end
		return(parse_response(response, 'QueryNetConfigResponse')['returnval'])
	end
	
	def queryOptions(omMor, name)
		response = invoke("n1:QueryOptions") do |message|
			message.add "n1:_this", omMor do |i|
				i.set_attr "type", omMor.vimType
			end
			message.add "n1:name", name
		end
		return(parse_response(response, 'QueryOptionsResponse')['returnval'])
	end
	
	def queryPerf(perfManager, querySpec)
		response = invoke("n1:QueryPerf") do |message|
			message.add "n1:_this", perfManager do |i|
				i.set_attr "type", perfManager.vimType
			end
			if querySpec.kind_of?(Array)
				querySpec.each do |qs|
					message.add "n1:querySpec" do |i|
						i.set_attr "xsi:type", qs.xsiType
						marshalObj(i, qs)
					end
				end
			else
				message.add "n1:querySpec" do |i|
					i.set_attr "xsi:type", querySpec.xsiType
					marshalObj(i, querySpec)
				end
			end
		end
		return(parse_response(response, 'QueryPerfResponse')['returnval'])
	end
	
	def queryPerfComposite(perfManager, querySpec)
		response = invoke("n1:QueryPerfComposite") do |message|
			message.add "n1:_this", perfManager do |i|
				i.set_attr "type", perfManager.vimType
			end
			message.add "n1:querySpec" do |i|
				i.set_attr "xsi:type", querySpec.xsiType
				marshalObj(i, querySpec)
			end
		end
		return(parse_response(response, 'QueryPerfCompositeResponse')['returnval'])
	end
	
	def queryPerfProviderSummary(perfManager, entity)
		response = invoke("n1:QueryPerfProviderSummary") do |message|
			message.add "n1:_this", perfManager do |i|
				i.set_attr "type", perfManager.vimType
			end
			message.add "n1:entity", entity do |i|
				i.set_attr "type", entity.vimType
			end
		end
		return(parse_response(response, 'QueryPerfProviderSummaryResponse')['returnval'])
	end
	
	def readNextEvents(ehcMor, maxCount)
		response = invoke("n1:ReadNextEvents") do |message|
			message.add "n1:_this", ehcMor do |i|
				i.set_attr "type", ehcMor.vimType
			end
			message.add "n1:maxCount", maxCount 
		end
		return(parse_response(response, 'ReadNextEventsResponse')['returnval'])
	end
	
	def readPreviousEvents(ehcMor, maxCount)
		response = invoke("n1:ReadPreviousEvents") do |message|
			message.add "n1:_this", ehcMor do |i|
				i.set_attr "type", ehcMor.vimType
			end
			message.add "n1:maxCount", maxCount 
		end
		return(parse_response(response, 'ReadPreviousEventsResponse')['returnval'])
	end
	
	def rebootGuest(vmMor)
		response = invoke("n1:RebootGuest") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'RebootGuestResponse'))
	end
	
	def rebootHost_Task(hMor, force=false)
		response = invoke("n1:RebootHost_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:force", force.to_s
		end
		return(parse_response(response, 'RebootHost_TaskResponse'))['returnval']
	end
	
	def reconfigureAlarm(aMor, aSpec)
		response = invoke("n1:ReconfigureAlarm") do |message|
			message.add "n1:_this", aMor do |i|
				i.set_attr "type", aMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", aSpec.xsiType
				marshalObj(i, aSpec)
			end
		end
		return(parse_response(response, 'ReconfigureAlarmResponse'))
	end
	
	def reconfigVM_Task(vmMor, vmConfigSpec)
		response = invoke("n1:ReconfigVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
			message.add "n1:spec" do |i|
				i.set_attr "xsi:type", vmConfigSpec.xsiType
				marshalObj(i, vmConfigSpec)
			end
		end		
		return(parse_response(response, 'ReconfigVM_TaskResponse')['returnval'])
	end
	
	def refreshFirewall(fwsMor)
		response = invoke("n1:RefreshFirewall") do |message|
			message.add "n1:_this", fwsMor do |i|
				i.set_attr "type", fwsMor.vimType
			end
		end
		return(parse_response(response, 'RefreshFirewallResponse'))
	end
	
	def refreshNetworkSystem(nsMor)
		response = invoke("n1:RefreshNetworkSystem") do |message|
			message.add "n1:_this", nsMor do |i|
				i.set_attr "type", nsMor.vimType
			end
		end
		return(parse_response(response, 'RefreshNetworkSystemResponse'))
	end
	
	def refreshServices(ssMor)
		response = invoke("n1:RefreshServices") do |message|
			message.add "n1:_this", ssMor do |i|
				i.set_attr "type", ssMor.vimType
			end
		end
		return(parse_response(response, 'RefreshServicesResponse'))
	end
	
	def registerVM_Task(fMor, path, name, asTemplate, pmor, hmor)
		response = invoke("n1:RegisterVM_Task") do |message|
			message.add "n1:_this", fMor do |i|
				i.set_attr "type", fMor.vimType
			end
			message.add "n1:path", path
			message.add "n1:name", name if name
			message.add "n1:asTemplate", asTemplate
			message.add "n1:pool", pmor do |i|
				i.set_attr "type", pmor.vimType
			end if pmor
			message.add "n1:host", hmor do |i|
				i.set_attr "type", hmor.vimType
			end if hmor
		end		
		return(parse_response(response, 'RegisterVM_TaskResponse')['returnval'])
	end
	
	def removeAlarm(aMor)
		response = invoke("n1:RemoveAlarm") do |message|
			message.add "n1:_this", aMor do |i|
				i.set_attr "type", aMor.vimType
			end
		end
		return(parse_response(response, 'RemoveAlarmResponse'))
	end
	
	def removeAllSnapshots_Task(vmMor)
		response = invoke("n1:RemoveAllSnapshots_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end		
		return(parse_response(response, 'RemoveAllSnapshots_TaskResponse')['returnval'])
	end
	
	def removeSnapshot_Task(snMor, subTree)
		response = invoke("n1:RemoveSnapshot_Task") do |message|
			message.add "n1:_this", snMor do |i|
				i.set_attr "type", snMor.vimType
			end
			message.add "n1:removeChildren", subTree
		end		
		return(parse_response(response, 'RemoveSnapshot_TaskResponse')['returnval'])
	end
	
	def renameSnapshot(snMor, name, desc)
		response = invoke("n1:RenameSnapshot") do |message|
			message.add "n1:_this", snMor do |i|
				i.set_attr "type", snMor.vimType
			end
			message.add "n1:name", name if name
			message.add "n1:description", desc if desc
		end		
		return(parse_response(response, 'RenameSnapshotResponse'))
	end
	
	def resetCollector(collectorMor)
		response = invoke("n1:ResetCollector") do |message|
			message.add "n1:_this", collectorMor do |i|
				i.set_attr "type", collectorMor.vimType
			end
		end
		return(parse_response(response, 'ResetCollectorResponse'))
	end
	
	def resetVM_Task(vmMor)
		response = invoke("n1:ResetVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'ResetVM_TaskResponse')['returnval'])
	end
	
	def restartService(ssMor, skey)
		response = invoke("n1:RestartService") do |message|
			message.add "n1:_this", ssMor do |i|
				i.set_attr "type", ssMor.vimType
			end
			message.add "n1:id", skey
		end
		return(parse_response(response, 'RestartServiceResponse'))
	end
	
	def retrieveProperties(propCol, specSet)
		response = invoke("n1:RetrieveProperties") do |message|
			message.add "n1:_this", propCol do |i|
				i.set_attr "type", propCol.vimType
			end
			message.add "n1:specSet" do |i|
				i.set_attr "xsi:type", "PropertyFilterSpec"
				marshalObj(i, specSet)
			end
		end		
		return(parse_response(response, 'RetrievePropertiesResponse')['returnval'])
	end
	
	def retrieveServiceContent
		response = invoke("n1:RetrieveServiceContent") do |message|
			message.add "n1:_this", @serviceInstanceMor do |i|
				i.set_attr "type", @serviceInstanceMor.vimType
			end
		end
		return(parse_response(response, 'RetrieveServiceContentResponse')['returnval'])
	end
	
	def revertToCurrentSnapshot_Task(vmMor)
		response = invoke("n1:RevertToCurrentSnapshot_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end		
		return(parse_response(response, 'RevertToCurrentSnapshot_TaskResponse')['returnval'])
	end
	
	def revertToSnapshot_Task(snMor)
		response = invoke("n1:RevertToSnapshot_Task") do |message|
			message.add "n1:_this", snMor do |i|
				i.set_attr "type", snMor.vimType
			end
		end		
		return(parse_response(response, 'RevertToSnapshot_TaskResponse')['returnval'])
	end
	
	def rewindCollector(collectorMor)
		response = invoke("n1:RewindCollector") do |message|
			message.add "n1:_this", collectorMor do |i|
				i.set_attr "type", collectorMor.vimType
			end
		end
		return(parse_response(response, 'RewindCollectorResponse'))
	end
	
	def searchDatastore_Task(browserMor, dsPath, searchSpec)
		response = invoke("n1:SearchDatastore_Task") do |message|
			message.add "n1:_this", browserMor do |i|
				i.set_attr "type", browserMor.vimType
			end
			message.add "n1:datastorePath", dsPath
			message.add "n1:searchSpec" do |i|
				i.set_attr "xsi:type", searchSpec.xsiType
				marshalObj(i, searchSpec)
			end if searchSpec
		end		
		return(parse_response(response, 'SearchDatastore_TaskResponse')['returnval'])
	end
	
	def searchDatastoreSubFolders_Task(browserMor, dsPath, searchSpec)
		response = invoke("n1:SearchDatastoreSubFolders_Task") do |message|
			message.add "n1:_this", browserMor do |i|
				i.set_attr "type", browserMor.vimType
			end
			message.add "n1:datastorePath", dsPath
			message.add "n1:searchSpec" do |i|
				i.set_attr "xsi:type", searchSpec.xsiType
				marshalObj(i, searchSpec)
			end if searchSpec
		end		
		return(parse_response(response, 'SearchDatastoreSubFolders_TaskResponse')['returnval'])
	end
	
	def selectVnicForNicType(vnmMor, nicType, device)
		response = invoke("n1:SelectVnicForNicType") do |message|
			message.add "n1:_this", vnmMor do |i|
				i.set_attr "type", vnmMor.vimType
			end
			message.add "n1:nicType", nicType
			message.add "n1:device", device
		end
		return(parse_response(response, 'SelectVnicForNicTypeResponse'))
	end
	
	def setCollectorPageSize(collector, maxCount)
		response = invoke("n1:SetCollectorPageSize") do |message|
			message.add "n1:_this", collector do |i|
				i.set_attr "type", collector.vimType
			end
			message.add "n1:maxCount", maxCount
		end		
		return(parse_response(response, 'SetCollectorPageSizeResponse'))
	end
	
	def setField(cfManager, mor, key, value)
		response = invoke("n1:SetField") do |message|
			message.add "n1:_this", cfManager do |i|
				i.set_attr "type", cfManager.vimType
			end
			message.add "n1:entity", mor do |i|
				i.set_attr "type", mor.vimType
			end
			message.add "n1:key", key
			message.add "n1:value", value
		end
		return(parse_response(response, 'SetFieldResponse'))
	end
	
	def setTaskDescription(tmor, description)
		response = invoke("n1:SetTaskDescription") do |message|
			message.add "n1:_this", tmor do |i|
				i.set_attr "type", tmor.vimType
			end
			message.add "n1:description" do |i|
				i.set_attr "xsi:type", description.xsiType
				marshalObj(i, description)
			end
		end
		return(parse_response(response, 'SetTaskDescriptionResponse'))
	end
	
	def setTaskState(tmor, state, result=nil, fault=nil)
		response = invoke("n1:SetTaskState") do |message|
			message.add "n1:_this", tmor do |i|
				i.set_attr "type", tmor.vimType
			end
			message.add "n1:state", state do |i|
				i.set_attr "xsi:type", "TaskInfoState"
			end
			message.add "n1:result" do |i|
				i.set_attr "xsi:type", result.xsiType
				marshalObj(i, result)
			end if result
			message.add "n1:fault" do |i|
				i.set_attr "xsi:type", fault.xsiType
				marshalObj(i, fault)
			end if fault
		end
		return(parse_response(response, 'SetTaskStateResponse'))
	end
	
	def shutdownGuest(vmMor)
		response = invoke("n1:ShutdownGuest") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'ShutdownGuestResponse'))
	end
	
	def shutdownHost_Task(hMor, force=false)
		response = invoke("n1:ShutdownHost_Task") do |message|
			message.add "n1:_this", hMor do |i|
				i.set_attr "type", hMor.vimType
			end
			message.add "n1:force", force.to_s
		end
		return(parse_response(response, 'ShutdownHost_TaskResponse'))['returnval']
	end
	
	def standbyGuest(vmMor)
		response = invoke("n1:StandbyGuest") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'StandbyGuestResponse'))
	end
	
	def startService(ssMor, skey)
		response = invoke("n1:StartService") do |message|
			message.add "n1:_this", ssMor do |i|
				i.set_attr "type", ssMor.vimType
			end
			message.add "n1:id", skey
		end
		return(parse_response(response, 'StartServiceResponse'))
	end
	
	def stopService(ssMor, skey)
		response = invoke("n1:StopService") do |message|
			message.add "n1:_this", ssMor do |i|
				i.set_attr "type", ssMor.vimType
			end
			message.add "n1:id", skey
		end
		return(parse_response(response, 'StopServiceResponse'))
	end
	
	def suspendVM_Task(vmMor)
		response = invoke("n1:SuspendVM_Task") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'SuspendVM_TaskResponse')['returnval'])
	end
	
	def uninstallService(ssMor, skey)
		response = invoke("n1:UninstallService") do |message|
			message.add "n1:_this", ssMor do |i|
				i.set_attr "type", ssMor.vimType
			end
			message.add "n1:id", skey
		end
		return(parse_response(response, 'UninstallServiceResponse'))
	end
	
	def unregisterVM(vmMor)
		response = invoke("n1:UnregisterVM") do |message|
			message.add "n1:_this", vmMor do |i|
				i.set_attr "type", vmMor.vimType
			end
		end
		return(parse_response(response, 'UnregisterVMResponse'))
	end
	
	def updateDefaultPolicy(fwsMor, defaultPolicy)
		response = invoke("n1:UpdateDefaultPolicy") do |message|
			message.add "n1:_this", fwsMor do |i|
				i.set_attr "type", fwsMor.vimType
			end
			message.add "n1:defaultPolicy" do |i|
				i.set_attr "xsi:type", defaultPolicy.xsiType
				marshalObj(i, defaultPolicy)
			end
		end
		return(parse_response(response, 'UpdateDefaultPolicyResponse'))
	end
	
	def updateServicePolicy(sMor, skey, policy)
		response = invoke("n1:UpdateServicePolicy") do |message|
			message.add "n1:_this", sMor do |i|
				i.set_attr "type", sMor.vimType
			end
			message.add "n1:id", skey
			message.add "n1:policy", policy
		end
		return(parse_response(response, 'UpdateServicePolicyResponse'))
	end
	
	def updateSoftwareInternetScsiEnabled(hssMor, enabled)
		response = invoke("n1:UpdateSoftwareInternetScsiEnabled") do |message|
			message.add "n1:_this", hssMor do |i|
				i.set_attr "type", hssMor.vimType
			end
			message.add "n1:enabled", enabled.to_s
		end
		return(parse_response(response, 'UpdateSoftwareInternetScsiEnabledResponse'))
	end
	
	def waitForUpdates(propCol, version=nil)
		response = invoke("n1:WaitForUpdates") do |message|
			message.add "n1:_this", propCol do |i|
				i.set_attr "type", propCol.vimType
			end
			message.add "n1:version", version if version
		end
		return(parse_response(response, 'WaitForUpdatesResponse')['returnval'])
	end
	
	def xmlToCustomizationSpecItem(csmMor, specItemXml)
		response = invoke("n1:XmlToCustomizationSpecItem") do |message|
			message.add "n1:_this", csmMor do |i|
				i.set_attr "type", csmMor.vimType
			end
			message.add "n1:specItemXml", specItemXml
		end
		return(parse_response(response, 'XmlToCustomizationSpecItemResponse')['returnval'])
	end
	
	private
	
	def setNameSpace(ns)
		@ns = { 'n1' => ns }
		on_create_document do |doc|
			doc.alias 'n1', ns
			doc.find("Envelope").set_attr "xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance"
		end
	end
	
	def marshalObj(node, obj)
		if obj.kind_of? Array
            obj.each do |v|
				marshalObj(node, v)
			end
        elsif obj.kind_of? VimHash
            obj.each_arg do |k, v|
				if v.kind_of? Array
					v.each do |av|
						node.add "n1:#{k}" do |i|
							marshalObj(i, av)
							i.set_attr "xsi:type", "n1:#{av.xsiType}" if av.respond_to?(:xsiType) && av.xsiType
							i.set_attr "type", v.vimType if v.respond_to?(:vimType) && v.vimType
						end
					end
				else
					node.add "n1:#{k}" do |i|
						marshalObj(i, v)
						i.set_attr "type", v.vimType if v.respond_to?(:vimType) && v.vimType
						i.set_attr "xsi:type", "n1:#{v.xsiType}" if v.respond_to?(:xsiType) && v.xsiType
					end
				end
			end
        else
            node.set_value(obj)
		end
	end
	
	def parse_response(response, rType)
	    doc  = response.document
	    raise "Response <#{response.inspect}> has no XML document" if doc.nil?
	    search_path = "//n1:#{rType}"
		node = doc.xpath(search_path, @ns).first
	    raise "Node (search=<#{search_path}> namespace=<#{@ns}>) not found in XML document <#{doc.inspect}>" if node.nil?
		ur   = unmarshal_response(node, rType)
		# puts
		# puts "***** #{rType}"
		# dumpObj(ur)
		# puts
		return(ur)
	end
	
	def unmarshal_response(node, vType=nil)
		return(node.text) if node.text?
		
		vimType = node.attribute_with_ns('type', nil)
		vimType = vimType.value if vimType
		xsiType = node.attribute_with_ns('type', 'http://www.w3.org/2001/XMLSchema-instance')
		xsiType = xsiType.value if xsiType
		xsiType ||= vType.to_s
		
		if node.children.length == 1 && (c = node.child) && c.text?
			return VimString.new(c.text, vimType, xsiType)
		end
		if xsiType == "SOAP::SOAPString"
			return VimString.new("", vimType, xsiType)
		end
		
		if xsiType =~ /^ArrayOf(.*)$/
			nextType = $1
			obj = VimArray.new(xsiType)
			node.children.each do |c|
				next if c.blank?
				obj << unmarshal_response(c, nextType)
			end
			return(obj)
		end
		
		aih = VimMappingRegistry.argInfoMap(xsiType)
		obj = VimHash.new(xsiType)
		
		node.children.each do |c|
			next if c.blank?
			
			ai = aih[c.name] if aih
			
			if !(v = obj[c.name])
				v = obj[c.name] = VimArray.new("ArrayOf#{ai[:type]}") if ai && ai[:isArray]
			end
			
			nextType = (ai ? ai[:type] : nil)
			
			if v.kind_of?(Array)
				obj[c.name] << unmarshal_response(c, nextType)
			else
				obj[c.name] = unmarshal_response(c, nextType)
			end
		end
		return(obj)
	end
	
end
