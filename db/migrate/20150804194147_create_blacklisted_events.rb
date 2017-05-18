class CreateBlacklistedEvents < ActiveRecord::Migration[4.2]
  def change
    create_table :blacklisted_events do |t|
      t.string  :event_name
      t.string  :provider_model
      t.bigint  :ems_id
      t.boolean :system
      t.boolean :enabled
      t.timestamps :null => true
    end
  end
end
