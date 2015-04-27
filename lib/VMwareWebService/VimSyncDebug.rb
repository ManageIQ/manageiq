require_relative "../util/SyncDebug"
require "vim_base_sync_debug"

module VimSyncDebug
  def self.extended(obj)
    obj.cacheLock.extend(SyncDebug_m)
    obj.cacheLock.lock_name = "#{obj.class.name}#cacheLock(#{obj.connId})"
    VimBaseSyncDebug.vsd_set_callbacks(obj.cacheLock)
    obj.cacheLock.watchdog_enabled = true

    obj.configLock.extend(SyncDebug_m)
    obj.configLock.lock_name = "#{obj.class.name}#configLock(#{obj.connId})"
    VimBaseSyncDebug.vsd_set_callbacks(obj.configLock)
    obj.configLock.watchdog_enabled = true
  end
end
