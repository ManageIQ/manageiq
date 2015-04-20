class RemoveMiqProxyModels < ActiveRecord::Migration
  def up
    remove_index "miq_proxies", "guid"
    remove_index "miq_proxies", "host_id"
    remove_index "miq_proxies", "vm_id"
    drop_table   "miq_proxies"

    drop_table   "miq_proxies_product_updates"

    drop_table   "product_updates"

    remove_index "proxy_tasks", "miq_proxy_id"
    drop_table   "proxy_tasks"
  end

  def down
    create_table "miq_proxies", :force => true do |t|
      t.string   "guid",             :limit => 36
      t.string   "name"
      t.text     "settings"
      t.datetime "last_heartbeat"
      t.string   "version"
      t.string   "ws_port"
      t.integer  "host_id",          :limit => 8
      t.integer  "vm_id",            :limit => 8
      t.datetime "created_on"
      t.datetime "updated_on"
      t.text     "capabilities"
      t.string   "power_state"
      t.string   "upgrade_status"
      t.string   "upgrade_message"
      t.text     "remote_config"
      t.string   "upgrade_settings"
    end

    add_index "miq_proxies", "guid"
    add_index "miq_proxies", "host_id"
    add_index "miq_proxies", "vm_id"

    create_table "miq_proxies_product_updates", :id => false, :force => true do |t|
      t.integer "product_update_id", :limit => 8
      t.integer "miq_proxy_id",      :limit => 8
    end

    create_table "product_updates", :force => true do |t|
      t.string   "name"
      t.string   "description"
      t.string   "md5"
      t.string   "version"
      t.string   "build"
      t.string   "component"
      t.string   "platform"
      t.string   "arch"
      t.string   "update_type"
      t.string   "vmdb_schema_version"
      t.datetime "created_on"
      t.datetime "updated_on"
    end

    create_table "proxy_tasks", :force => true do |t|
      t.integer  "priority"
      t.text     "command"
      t.string   "state"
      t.datetime "created_on"
      t.datetime "updated_on"
      t.integer  "miq_proxy_id", :limit => 8
    end

    add_index "proxy_tasks", "miq_proxy_id"
  end
end
