class ExpandColumnsInMiqAeFieldsAndValues < ActiveRecord::Migration
  def self.up
    change_column :miq_ae_fields, :condition, :text
    change_column :miq_ae_values, :condition, :text
    change_column :miq_ae_values, :collect,   :text
  end

  def self.down
    change_column :miq_ae_fields, :condition, :string
    change_column :miq_ae_values, :condition, :string
    change_column :miq_ae_values, :collect,   :string
  end
end
