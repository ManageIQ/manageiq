class AddOnXxxColumnsToMiqAeFields < ActiveRecord::Migration
  def self.up
    add_column    :miq_ae_fields, :on_entry, :text
    add_column    :miq_ae_fields, :on_exit,  :text
    add_column    :miq_ae_fields, :on_error, :text
  end

  def self.down
    remove_column :miq_ae_fields, :on_entry
    remove_column :miq_ae_fields, :on_exit
    remove_column :miq_ae_fields, :on_error
  end
end
