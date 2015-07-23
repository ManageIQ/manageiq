require 'util/SyncDebug'
require 'VMwareWebService/vim_base_sync_debug'

module BrokerSyncDebug
  def connection_lock
    alloc_sync_lock("#{self.class.name}#connectionLock")
  end

  def config_lock
    alloc_sync_lock("#{self.class.name}#configLock")
  end

  def sync_for_lock_hash(key)
    alloc_sync_lock("#{self.class.name}#lockHash[#{key}]")
  end

  def sync_for_drb
    alloc_sync_lock("DRB#mutex")
  end

  def sync_for_drb_drbconn
    alloc_sync_lock("DRb::DRbConn#mutex")
  end

  def alloc_sync_lock(lock_name)
    lock = Sync.new
    lock.extend(SyncDebug_m)
    lock.lock_name = lock_name
    VimBaseSyncDebug.vsd_set_callbacks(lock)
    lock.watchdog_enabled = true
    lock
  end
end
