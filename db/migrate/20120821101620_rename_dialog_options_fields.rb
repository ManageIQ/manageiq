class RenameDialogOptionsFields < ActiveRecord::Migration
  def change
    rename_column :dialog_fields, :display_options,        :display_method_options
    rename_column :dialog_fields, :required_options,       :required_method_options
    rename_column :dialog_fields, :values_options,         :values_method_options

    add_column    :dialog_groups, :display_method,         :string
    add_column    :dialog_groups, :display_method_options, :text

    add_column    :dialog_tabs,   :display_method,         :string
    add_column    :dialog_tabs,   :display_method_options, :text
  end
end
