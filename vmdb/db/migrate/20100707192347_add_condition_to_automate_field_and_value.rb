class AddConditionToAutomateFieldAndValue < ActiveRecord::Migration
  def self.up
    add_column    :miq_ae_fields,        :condition,        :string
    add_column    :miq_ae_values,        :condition,        :string
  end

  def self.down
    remove_column :miq_ae_fields,        :condition
    remove_column :miq_ae_values,        :condition
  end
end
