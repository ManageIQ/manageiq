$:.push("#{File.dirname(__FILE__)}/../VixDiskLib")

require 'DMiqVim'
require 'MiqVimVm'
require 'MiqVimHost'
require 'MiqVimDataStore'
require 'MiqVimPerfHistory'
require 'MiqVimFolder'
require 'MiqVimEventHistoryCollector'
require 'MiqCustomFieldsManager'
require 'MiqVimAlarmManager'
require 'MiqVimCustomizationSpecManager'

#begin
	#require 'VixDiskLib'
	#class VdlConnection
		#alias :release :disconnect
	#end
#rescue LoadError
	## Ignore on systems that don't have VixDiskLib
	#class VdlConnection
		#def release
		#end
	#end
#end

require 'drb'

$miqBrokerObjRegistry			= Hash.new { |h, k| h[k] = Array.new }
$miqBrokerObjRegistryByConn		= Hash.new { |h, k| h[k] = Array.new }
$miqBrokerObjIdMap				= Hash.new
$miqBrokerObjCounts				= Hash.new
$miqBrokerObjHold				= Hash.new
$miqBrokerObjRegistryLock		= Sync.new

module MiqBrokerObjRegistry
	def holdBrokerObj
		$vim_log.info "MiqBrokerObjRegistry.holdBrokerObj: #{self.class.to_s} object_id: #{self.object_id} TEMP HOLD"
		$miqBrokerObjRegistryLock.synchronize(:EX) do
			$miqBrokerObjHold[self.object_id] = self
		end
		return nil
	end
	
	def registerBrokerObj(id)
		$vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class.to_s} object_id: #{self.object_id} => SessionId: #{id}"
		$miqBrokerObjRegistryLock.synchronize(:EX) do
			$miqBrokerObjRegistry[id] << self
			
			if $miqBrokerObjHold.has_key?(self.object_id)
				$vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class.to_s} object_id: #{self.object_id} TEMP HOLD RELEASE"
				$miqBrokerObjHold.delete(self.object_id)
			end
			
			if defined? @invObj
				connKey = "#{@invObj.server}_#{@invObj.username}"
				$vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class.to_s} object_id: #{self.object_id} => Connection: #{connKey}"
				$miqBrokerObjRegistryByConn[connKey] << self
			end
			
			$miqBrokerObjIdMap[self.object_id] = id
			$miqBrokerObjCounts[self.class.to_s] = 0 unless $miqBrokerObjCounts[self.class.to_s]
			$miqBrokerObjCounts[self.class.to_s] += 1
		end
		return nil
	end
	
	def unregisterBrokerObj
		$miqBrokerObjRegistryLock.synchronize(:EX) do
			return if !(id = $miqBrokerObjIdMap[self.object_id])
			$vim_log.info "MiqBrokerObjRegistry.unregisterBrokerObj: #{self.class.to_s} object_id: #{self.object_id} => SessionId: #{id}"
			$miqBrokerObjRegistry[id].delete(self)
			$miqBrokerObjRegistry.delete(id) if $miqBrokerObjRegistry[id].empty?
			if defined? @invObj
				connKey = "#{@invObj.server}_#{@invObj.username}"
				$vim_log.info "MiqBrokerObjRegistry.unregisterBrokerObj: #{self.class.to_s} object_id: #{self.object_id} => Connection: #{connKey}"
				$miqBrokerObjRegistryByConn[connKey].delete(self)
				$miqBrokerObjRegistryByConn.delete(connKey) if $miqBrokerObjRegistryByConn[connKey].empty?
			end
			$miqBrokerObjIdMap.delete(self.object_id)
			$miqBrokerObjCounts[self.class.to_s] -= 1
		end
		return nil
	end
	
	def release
		$vim_log.info "MiqBrokerObjRegistry.release: #{self.class.to_s} object_id: #{self.object_id}"
		unregisterBrokerObj
		release_orig
	end
end

module MiqBrokerVimConnectionCheck
	def connectionRemoved?
		return false unless self.respond_to?(:invObj)
		return false unless self.invObj.respond_to?(:connectionRemoved?)
		return self.invObj.connectionRemoved?
	end
end

#class VdlConnection
	#alias :release_orig :release
	#remove_method :release
	#include MiqBrokerObjRegistry
#end

class MiqVimVm
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimHost
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimDataStore
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include DMiqVimSync
	include MiqBrokerVimConnectionCheck
end

class MiqVimPerfHistory
    alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimFolder
    alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimCluster
	alias :release_orig :release
	remove_method :release
	include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimEventHistoryCollector
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqCustomFieldsManager
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimAlarmManager
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

class MiqVimCustomizationSpecManager
	alias :release_orig :release
	remove_method :release
    include DRb::DRbUndumped
	include MiqBrokerObjRegistry
	include MiqBrokerVimConnectionCheck
end

#
# Instances of the following classes are maintained in MiqVimHost objects,
# so there's no need to include it in the MiqBrokerObjRegistry.
#
class MiqHostFirewallSystem
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostAdvancedOptionManager
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostDatastoreSystem
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostStorageSystem
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostServiceSystem
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostNetworkSystem
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end

class MiqHostVirtualNicManager
	include DRb::DRbUndumped
	include MiqBrokerVimConnectionCheck
end
