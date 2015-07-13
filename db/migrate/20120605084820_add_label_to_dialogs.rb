class AddLabelToDialogs < ActiveRecord::Migration
  def change
    add_column :dialogs    ,   :label, :string
    add_column :dialog_tabs,   :label, :string
    add_column :dialog_groups, :label, :string
    add_column :dialog_fields, :label, :string
  end
end
