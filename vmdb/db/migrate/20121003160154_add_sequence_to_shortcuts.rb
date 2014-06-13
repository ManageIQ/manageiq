class AddSequenceToShortcuts < ActiveRecord::Migration
  def change
    add_column :miq_shortcuts,        :sequence, :integer
    add_column :miq_widget_shortcuts, :sequence, :integer
  end
end
