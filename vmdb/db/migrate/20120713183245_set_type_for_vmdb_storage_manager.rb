class SetTypeForVmdbStorageManager < ActiveRecord::Migration
  class StorageManager < ActiveRecord::Base; end

  def up
    StorageManager.where(:agent_type => 'VMDB').update_all(:type => 'CimVmdbAgent')
  end

  def down
    StorageManager.where(:type => 'CimVmdbAgent').update_all(:type => nil)
  end
end
