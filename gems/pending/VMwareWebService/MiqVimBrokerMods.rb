require 'VMwareWebService/DMiqVim'
require 'VMwareWebService/MiqVimVm'
require 'VMwareWebService/MiqVimHost'
require 'VMwareWebService/MiqVimDataStore'
require 'VMwareWebService/MiqVimPerfHistory'
require 'VMwareWebService/MiqVimFolder'
require 'VMwareWebService/MiqVimEventHistoryCollector'
require 'VMwareWebService/MiqCustomFieldsManager'
require 'VMwareWebService/MiqVimAlarmManager'
require 'VMwareWebService/MiqVimCustomizationSpecManager'

# begin
# require 'VixDiskLib'
# class VdlConnection
# alias :release :disconnect
# end
# rescue LoadError
# # Ignore on systems that don't have VixDiskLib
# class VdlConnection
# def release
# end
# end

require 'drb'

$miqBrokerObjRegistry     = Hash.new { |h, k| h[k] = [] }
$miqBrokerObjRegistryByConn   = Hash.new { |h, k| h[k] = [] }
$miqBrokerObjIdMap        = {}
$miqBrokerObjCounts       = {}
$miqBrokerObjHold       = {}
$miqBrokerObjRegistryLock   = Sync.new

module MiqBrokerObjRegistry
  def holdBrokerObj
    $vim_log.info "MiqBrokerObjRegistry.holdBrokerObj: #{self.class} object_id: #{object_id} TEMP HOLD"
    $miqBrokerObjRegistryLock.synchronize(:EX) do
      $miqBrokerObjHold[object_id] = self
    end
    nil
  end

  def registerBrokerObj(id)
    $vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class} object_id: #{object_id} => SessionId: #{id}"
    $miqBrokerObjRegistryLock.synchronize(:EX) do
      $miqBrokerObjRegistry[id] << self

      if $miqBrokerObjHold.key?(object_id)
        $vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class} object_id: #{object_id} TEMP HOLD RELEASE"
        $miqBrokerObjHold.delete(object_id)
      end

      if defined? @invObj
        connKey = "#{@invObj.server}_#{@invObj.username}"
        $vim_log.info "MiqBrokerObjRegistry.registerBrokerObj: #{self.class} object_id: #{object_id} => Connection: #{connKey}"
        $miqBrokerObjRegistryByConn[connKey] << self
      end

      $miqBrokerObjIdMap[object_id] = id
      $miqBrokerObjCounts[self.class.to_s] = 0 unless $miqBrokerObjCounts[self.class.to_s]
      $miqBrokerObjCounts[self.class.to_s] += 1
    end
    nil
  end

  def unregisterBrokerObj
    $miqBrokerObjRegistryLock.synchronize(:EX) do
      return unless (id = $miqBrokerObjIdMap[object_id])
      $vim_log.info "MiqBrokerObjRegistry.unregisterBrokerObj: #{self.class} object_id: #{object_id} => SessionId: #{id}"
      $miqBrokerObjRegistry[id].delete(self)
      $miqBrokerObjRegistry.delete(id) if $miqBrokerObjRegistry[id].empty?
      if defined? @invObj
        connKey = "#{@invObj.server}_#{@invObj.username}"
        $vim_log.info "MiqBrokerObjRegistry.unregisterBrokerObj: #{self.class} object_id: #{object_id} => Connection: #{connKey}"
        $miqBrokerObjRegistryByConn[connKey].delete(self)
        $miqBrokerObjRegistryByConn.delete(connKey) if $miqBrokerObjRegistryByConn[connKey].empty?
      end
      $miqBrokerObjIdMap.delete(object_id)
      $miqBrokerObjCounts[self.class.to_s] -= 1
    end
    nil
  end

  def release
    $vim_log.info "MiqBrokerObjRegistry.release: #{self.class} object_id: #{object_id}"
    unregisterBrokerObj
    release_orig
  end
end

module MiqBrokerVimConnectionCheck
  def connectionRemoved?
    return false unless self.respond_to?(:invObj)
    return false unless invObj.respond_to?(:connectionRemoved?)
    invObj.connectionRemoved?
  end
end

# class VdlConnection
# alias :release_orig :release
# remove_method :release
# include MiqBrokerObjRegistry
# end

class MiqVimVm
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimHost
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimDataStore
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include DMiqVimSync
  include MiqBrokerVimConnectionCheck
end

class MiqVimPerfHistory
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimFolder
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimCluster
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimEventHistoryCollector
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqCustomFieldsManager
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimAlarmManager
  alias_method :release_orig, :release
  remove_method :release
  include DRb::DRbUndumped
  include MiqBrokerObjRegistry
  include MiqBrokerVimConnectionCheck
end

class MiqVimCustomizationSpecManager
  alias_method :release_orig, :release
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
