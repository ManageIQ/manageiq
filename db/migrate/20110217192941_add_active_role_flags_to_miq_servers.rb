class AddActiveRoleFlagsToMiqServers < ActiveRecord::Migration
  def self.up
    add_column :miq_servers, :has_active_userinterface, :boolean
    add_column :miq_servers, :has_active_webservices,   :boolean
  end

  def self.down
    remove_column :miq_servers, :has_active_userinterface
    remove_column :miq_servers, :has_active_webservices
  end
end
