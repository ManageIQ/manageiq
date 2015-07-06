class AddCollectToAutomateValue < ActiveRecord::Migration
  def self.up
    add_column    :miq_ae_values,        :collect,        :string
  end

  def self.down
    remove_column :miq_ae_values,        :collect
  end
end
