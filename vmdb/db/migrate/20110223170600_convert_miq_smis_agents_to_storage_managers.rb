class ConvertMiqSmisAgentsToStorageManagers < ActiveRecord::Migration

  class Authentication < ActiveRecord::Base; end
  class StorageManager < ActiveRecord::Base
    self.inheritance_column = :_type_disabled  # disable STI
  end

  def self.up
    rename_table  :miq_smis_agents,   :storage_managers
    add_column    :storage_managers,  :parent_agent_id, :bigint
    add_column    :storage_managers,  :vendor,          :string
    add_column    :storage_managers,  :version,         :string
    add_column    :storage_managers,  :type,            :string
    add_column    :storage_managers,  :type_spec_data,  :text

    say_with_time("Update StorageManager type to MiqSmisAgent") do
      StorageManager.update_all(:type => 'MiqSmisAgent')
    end

    say_with_time("Update MiqSmisAgent references to StorageManager") do
      Authentication.where(:resource_type => 'MiqSmisAgent').update_all(:resource_type => 'StorageManager')
    end
  end

  def self.down
    say_with_time("Remove non-MiqSmisAgent StorageManagers") do
      sms = StorageManager.where(["type != ?", "MiqSmisAgent"]).select(:id)
      if sms.any?
        Authentication.where(:resource_type => "StorageManager", :resource_id => sms.collect(&:id)).delete_all
        sms.delete_all
      end
    end

    remove_column :storage_managers,  :parent_agent_id
    remove_column :storage_managers,  :vendor
    remove_column :storage_managers,  :version
    remove_column :storage_managers,  :type
    remove_column :storage_managers,  :type_spec_data
    rename_table  :storage_managers,  :miq_smis_agents

    say_with_time("Update StorageManager references to MiqSmisAgent") do
      Authentication.where(:resource_type => 'StorageManager').update_all(:resource_type => 'MiqSmisAgent')
    end
  end
end
