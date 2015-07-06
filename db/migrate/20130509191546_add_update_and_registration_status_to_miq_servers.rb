class AddUpdateAndRegistrationStatusToMiqServers < ActiveRecord::Migration
  def change
    add_column :miq_servers,  :rh_registered,       :boolean
    add_column :miq_servers,  :rh_subscribed,       :boolean
    add_column :miq_servers,  :last_update_check,   :string
    add_column :miq_servers,  :updates_available,   :boolean
  end
end
