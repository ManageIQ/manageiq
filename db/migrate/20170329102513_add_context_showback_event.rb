class AddContextShowbackEvent < ActiveRecord::Migration[5.0]
  def up
    add_column :showback_events, :context, :json, :default => {}
    add_index  :showback_events, :type_obj
  end

  def down
    remove_column  :showback_events, :context
    remove_index   :showback_events, :type_obj
  end
end
