class ConvertShowRefreshButtonAndLoadValuesOnInitToRealColumnsForDialogFields < ActiveRecord::Migration
  class DialogField < ActiveRecord::Base
    serialize :options, Hash
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :dialog_fields, :show_refresh_button, :boolean
    add_column :dialog_fields, :load_values_on_init, :boolean

    DialogField.all.each do |dialog_field|
      dialog_field.show_refresh_button = dialog_field.options.delete(:show_refresh_button)
      dialog_field.load_values_on_init = dialog_field.options.delete(:load_values_on_init)
      dialog_field.save
    end
  end

  def down
    DialogField.all.each do |dialog_field|
      dialog_field.options[:load_values_on_init] = dialog_field.load_values_on_init
      dialog_field.options[:show_refresh_button] = dialog_field.show_refresh_button
      dialog_field.save
    end

    remove_column :dialog_fields, :load_values_on_init
    remove_column :dialog_fields, :show_refresh_button
  end
end
