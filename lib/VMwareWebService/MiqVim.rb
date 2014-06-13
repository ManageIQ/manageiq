$:.push(File.dirname(__FILE__))
$:.push("#{File.dirname(__FILE__)}/../VixDiskLib")

require 'sync'

require 'MiqVimInventory'
require 'MiqVimVm'
require 'MiqVimVdlMod'
require 'MiqVimFolder'
require 'MiqVimCluster'
require 'MiqVimDataStore'
require 'MiqVimPerfHistory'
require 'MiqVimHost'
require 'MiqVimEventHistoryCollector'
require 'MiqCustomFieldsManager'
require 'MiqVimAlarmManager'
require 'MiqVimCustomizationSpecManager'

class MiqVim < MiqVimInventory
	
	include MiqVimVdlConnectionMod

	def initialize(server, username, password, cacheScope=nil)
	    super
	end
	
	def getVimVm(path)
		$vim_log.info "MiqVimMod.getVimVm: called"
		miqVimVm = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{path}" if !(vmh = virtualMachines_locked[path])
			miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
        end
		$vim_log.info "MiqVimMod.getVimVm: returning object #{miqVimVm.object_id}"
        return(miqVimVm)
	end # def getVimVm
	
	def getVimVmByMor(vmMor)
		$vim_log.info "MiqVimMod.getVimVmByMor: called"
		miqVimVm = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find VM: #{vmMor}" if !(vmh = virtualMachinesByMor_locked[vmMor])
			miqVimVm = MiqVimVm.new(self, conditionalCopy(vmh))
        end
		$vim_log.info "MiqVimMod.getVimVmByMor: returning object #{miqVimVm.object_id}"
		return(miqVimVm)
	end # def getVimVmByMor
	
	#
	# Returns a MiqVimVm object for the first VM found that
	# matches the criteria defined by the filter.
	#
	def getVimVmByFilter(filter)
		$vim_log.info "MiqVimMod.getVimVmByFilter: called"
		miqVimVm = nil
		@cacheLock.synchronize(:SH) do
	        vms = applyFilter(virtualMachinesByMor_locked.values, filter)
			raise MiqException::MiqVimResourceNotFound, "getVimVmByFilter: Could not find VM matching filter" if vms.empty?
			miqVimVm = MiqVimVm.new(self, conditionalCopy(vms[0]))
		end
		$vim_log.info "MiqVimMod.getVimVmByFilter: returning object #{miqVimVm.object_id}"
		return(miqVimVm)
	end # def getVimVmByFilter
	
	def getVimHost(name)
		$vim_log.info "MiqVimMod.getVimHost: called"
		miqVimHost = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{name}" if !(hh = hostSystems_locked[name])
			miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
        end
		$vim_log.info "MiqVimMod.getVimHost: returning object #{miqVimHost.object_id}"
        return(miqVimHost)
	end # def getVimHost
	
	def getVimHostByMor(hMor)
		$vim_log.info "MiqVimMod.getVimHostByMor: called"
		miqVimHost = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Host: #{hMor}" if !(hh = hostSystemsByMor_locked[hMor])
			miqVimHost = MiqVimHost.new(self, conditionalCopy(hh))
        end
		$vim_log.info "MiqVimMod.getVimHostByMor: returning object #{miqVimHost.object_id}"
		return(miqVimHost)
	end # def getVimHostByMor
	
	#
	# Returns a MiqVimHost object for the first Host found that
	# matches the criteria defined by the filter.
	#
	def getVimHostByFilter(filter)
		$vim_log.info "MiqVimMod.getVimHostByFilter: called"
		miqVimHost = nil
		@cacheLock.synchronize(:SH) do
	        ha = applyFilter(hostSystemsByMor_locked.values, filter)
			raise MiqException::MiqVimResourceNotFound, "getVimHostByFilter: Could not find Host matching filter" if ha.empty?
			miqVimHost = MiqVimHost.new(self, conditionalCopy(ha[0]))
		end
		$vim_log.info "MiqVimMod.getVimHostByFilter: returning object #{miqVimHost.object_id}"
		return(miqVimHost)
	end # def getVimHostByFilter
	
	def getVimFolder(name)
		$vim_log.info "MiqVimMod.getVimFolder: called"
		miqVimFolder = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{name}" if !(fh = folders_locked[name])
			miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
        end
		$vim_log.info "MiqVimMod.getVimFolder: returning object #{miqVimFolder.object_id}"
        return(miqVimFolder)
	end # def getVimFolder
	
	def getVimFolderByMor(fMor)
		$vim_log.info "MiqVimMod.getVimFolderByMor: called"
		miqVimFolder = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Folder: #{fMor}" if !(fh = foldersByMor_locked[fMor])
			miqVimFolder = MiqVimFolder.new(self, conditionalCopy(fh))
        end
		$vim_log.info "MiqVimMod.getVimFolderByMor: returning object #{miqVimFolder.object_id}"
        return(miqVimFolder)
	end # def getVimFolderByMor
	
	def getVimFolderByFilter(filter)
		$vim_log.info "MiqVimMod.getVimFolderByFilter: called"
		miqVimFolder = nil
		@cacheLock.synchronize(:SH) do
	        folders = applyFilter(foldersByMor_locked.values, filter)
			raise MiqException::MiqVimResourceNotFound, "getVimFolderByFilter: Could not find folder matching filter" if folders.empty?
			miqVimFolder = MiqVimFolder.new(self, conditionalCopy(folders[0]))
		end
		$vim_log.info "MiqVimMod.getVimFolderByFilter: returning object #{miqVimFolder.object_id}"
		return(miqVimFolder)
	end # def getVimFolderByFilter
	
	#
	# Cluster
	#
	def getVimCluster(name)
		$vim_log.info "MiqVimMod.getVimCluster: called"
		miqVimCluster = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{name}" if !(ch = clusterComputeResources_locked[name])
			miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
        end
		$vim_log.info "MiqVimMod.getVimCluster: returning object #{miqVimCluster.object_id}"
        return(miqVimCluster)
	end # def getVimCluster
	
	def getVimClusterByMor(cMor)
		$vim_log.info "MiqVimMod.getVimClusterByMor: called"
		miqVimCluster = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find Cluster: #{cMor}" if !(ch = clusterComputeResourcesByMor_locked[cMor])
			miqVimCluster = MiqVimCluster.new(self, conditionalCopy(ch))
        end
		$vim_log.info "MiqVimMod.getVimClusterByMor: returning object #{miqVimCluster.object_id}"
        return(miqVimCluster)
	end # def getVimClusterByMor
	
	def getVimClusterByFilter(filter)
		$vim_log.info "MiqVimMod.getVimClusterByFilter: called"
		miqVimCluster = nil
		@cacheLock.synchronize(:SH) do
	        clusters = applyFilter(clusterComputeResourcesByMor_locked.values, filter)
			raise MiqException::MiqVimResourceNotFound, "getVimClusterByFilter: Could not find Cluster matching filter" if clusters.empty?
			miqVimCluster = MiqVimCluster.new(self, conditionalCopy(clusters[0]))
		end
		$vim_log.info "MiqVimMod.getVimClusterByFilter: returning object #{miqVimCluster.object_id}"
		return(miqVimCluster)
	end # def getVimClusterByFilter
	
	
	#
	# DataStore
	#
	def getVimDataStore(dsName)
		$vim_log.info "MiqVimMod.getVimDataStore: called"
		miqVimDs = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsName}" if !(dsh = dataStores_locked[dsName])
			miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
        end
		$vim_log.info "MiqVimMod.getVimDataStore: returning object #{miqVimDs.object_id}"
        return(miqVimDs)
    end

	def getVimDataStoreByMor(dsMor)
		$vim_log.info "MiqVimMod.getVimDataStoreByMor: called"
		miqVimDs = nil
	    @cacheLock.synchronize(:SH) do
	        raise MiqException::MiqVimResourceNotFound, "Could not find datastore: #{dsMor}" if !(dsh = dataStoresByMor_locked[dsMor])
			miqVimDs = MiqVimDataStore.new(self, conditionalCopy(dsh))
        end
		$vim_log.info "MiqVimMod.getVimDataStoreByMor: returning object #{miqVimDs.object_id}"
        return(miqVimDs)
    end
    
    def getVimPerfHistory
		miqVimPh = MiqVimPerfHistory.new(self)
		$vim_log.info "MiqVimMod.getVimPerfHistory: returning object #{miqVimPh.object_id}"
        return(miqVimPh)
    end

	def getVimEventHistory(eventFilterSpec=nil, pgSize=20)
		miqVimEh = MiqVimEventHistoryCollector.new(self, eventFilterSpec, pgSize)
		$vim_log.info "MiqVimMod.getVimEventHistory: returning object #{miqVimEh.object_id}"
        return(miqVimEh)
	end
	
	def getMiqCustomFieldsManager
		miqVimCfm = MiqCustomFieldsManager.new(self)
		$vim_log.info "MiqVimMod.getMiqCustomFieldsManager: returning object #{miqVimCfm.object_id}"
        return(miqVimCfm)
    end

	def getVimAlarmManager
		miqVimAm = MiqVimAlarmManager.new(self)
		$vim_log.info "MiqVimMod.getVimAlarmManager: returning object #{miqVimAm.object_id}"
        return(miqVimAm)
	end
	
	def getVimCustomizationSpecManager
		miqVimCsm = MiqVimCustomizationSpecManager.new(self)
		$vim_log.info "MiqVimMod.getVimCustomizationSpecManager: returning object #{miqVimCsm.object_id}"
        return(miqVimCsm)
	end
    
    def disconnect
        super
    end
	
end # module MiqVim
