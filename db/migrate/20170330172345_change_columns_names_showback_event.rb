class ChangeColumnsNamesShowbackEvent < ActiveRecord::Migration[5.0]
  def up
    rename_column :showback_events, :id_obj,   :resource_id
    rename_column :showback_events, :type_obj, :resource_type
  end
  def down
    rename_column :showback_events, :resource_id,   :id_obj
    rename_column :showback_events, :resource_type, :type_obj
  end
end
