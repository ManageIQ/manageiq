class MiqHostStorageSystem
	
	attr_reader	:invObj
	
	def initialize(hssMor, invObj)
		@invObj = invObj
		@hssMor = hssMor
	end
	
	def fileSystemVolumeInfo
		@invObj.getMoProp(@hssMor, 'fileSystemVolumeInfo')['fileSystemVolumeInfo']
	end
	
	def multipathStateInfo
		@invObj.getMoProp(@hssMor, 'multipathStateInfo')['multipathStateInfo']
	end
	
	def storageDeviceInfo
		@invObj.getMoProp(@hssMor, 'storageDeviceInfo')['storageDeviceInfo']
	end
	
	#
	# hbaType:
	# 	HostBlockHba, HostFibreChannelHba, HostInternetScsiHba, HostParallelScsiHba 
	#
	def hostBusAdaptersByType(hbaType)
		storageDeviceInfo.hostBusAdapter.delete_if { |hba| hba.xsiType != hbaType }
	end
	
	def softwareInternetScsiEnabled?
		sise = @invObj.getMoProp(@hssMor, 'storageDeviceInfo.softwareInternetScsiEnabled')['storageDeviceInfo']['softwareInternetScsiEnabled']
		sise == 'true'
	end
	
	def updateSoftwareInternetScsiEnabled(enabled)
		@invObj.updateSoftwareInternetScsiEnabled(@hssMor, enabled)
	end
	
	def addInternetScsiSendTargets(iScsiHbaDevice, targets)
		ta = targets.kind_of?(Array) ? targets : [ targets ] 
		unless ta.first.kind_of?(VimHash)
			nta = VimArray.new("ArrayOfHostInternetScsiHbaSendTarget") do |nt|
				ta.each do |t|
					nt << VimHash.new("HostInternetScsiHbaSendTarget") { |st| st.address = t }
				end
			end
			ta = nta
		end
		@invObj.addInternetScsiSendTargets(@hssMor, iScsiHbaDevice, ta)
	end
	
	def addInternetScsiStaticTargets(iScsiHbaDevice, targets)
		@invObj.addInternetScsiStaticTargets(@hssMor, iScsiHbaDevice, targets)
	end
	
end # class MiqHostStorageSystem
