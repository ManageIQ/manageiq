class RemoveDefaultsFromMiqWidgets < ActiveRecord::Migration
  def up
    change_column_default('miq_widgets', :enabled, nil)
    change_column_default('miq_widgets', :read_only, nil)
  end

  def down
    change_column_default('miq_widgets', :enabled, true)
    change_column_default('miq_widgets', :read_only, false)
  end
end
