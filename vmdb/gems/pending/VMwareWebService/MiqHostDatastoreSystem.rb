class MiqHostDatastoreSystem
	
	attr_reader	:invObj
	
	def initialize(dssMor, invObj)
		@invObj = invObj
		@dssMor = dssMor
	end
	
	def capabilities
		@capabilities ||= @invObj.getMoProp(@dssMor, 'capabilities')['capabilities']
	end
	
	def datastore
		@invObj.getMoProp(@dssMor, 'datastore')['datastore']
	end
	
	def createNasDatastore(remoteHost, remotePath, localPath, accessMode="readWrite", type="nfs", userName=nil, password=nil)
		spec = VimHash.new('HostNasVolumeSpec') do |s|
			s.remoteHost	= remoteHost
			s.remotePath	= remotePath
			s.localPath		= localPath
			s.accessMode	= accessMode
			s.type			= type
			s.userName		= userName
			s.password		= password
		end
		@invObj.createNasDatastore(@dssMor, spec)
	end
	
	#
	# Utility method to add an existing NAS datastore to the host in question.
	#
	def addNasDatastoreByName(dsName, accessMode="readWrite")
		if (dsh = @invObj.dataStoresByFilter_local("summary.name" => dsName).first).nil?
			raise "MiqHostDatastoreSystem.addNasDatastoreByName: datastore #{sdName} not found"
		end
		
		unless dsh.summary.type.casecmp('nfs') == 0 || dsh.summary.type.casecmp('nas') == 0
			raise "MiqHostDatastoreSystem.addNasDatastoreByName: datastore #{dsName} is not NAS"
		end
		
		remoteHost	= dsh.info.nas.remoteHost
		remotePath	= dsh.info.nas.remotePath
		localPath	= dsh.info.nas.name
		type		= dsh.info.nas.type
		
		$vim_log.info "MiqHostDatastoreSystem.addNasDatastoreByName: remoteHost = #{remoteHost}, remotePath = #{remotePath}, localPath = #{localPath}"
		createNasDatastore(remoteHost, remotePath, localPath, accessMode, type)
	end
	
end # class MiqHostDatastoreSystem
