class CreateShowbackEvents < ActiveRecord::Migration[5.0]
  def up
    create_table :showback_events do |t|
      t.json       :data
      t.timestamp  :start_time  # when start the event
      t.timestamp  :end_time    # when finish the event
      t.bigint     :id_obj      # id of name model about reference the event in C&U
      t.string     :type_obj    # name model about reference the event in C&U
      t.bigint     :showback_configuration_id
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end
    add_index  :showback_events, :id_obj
    add_index  :showback_events, :showback_configuration_id
  end

  def down
    remove_index  :showback_events, :id_obj
    remove_index  :showback_events, :showback_configuration_id
    drop_table :showback_events
  end
end
