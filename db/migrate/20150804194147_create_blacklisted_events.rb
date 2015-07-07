class CreateBlacklistedEvents < ActiveRecord::Migration
  def change
    create_table :blacklisted_events do |t|
      t.string  :event_name
      t.string  :provider_model
      t.bigint  :ems_id
      t.boolean :system
      t.boolean :enabled
      t.timestamps
    end
  end
end
