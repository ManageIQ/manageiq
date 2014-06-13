class ConvertCustomSpecDescriptionToText < ActiveRecord::Migration
  def self.up
    change_column :customization_specs, :description, :text
  end

  def self.down
    change_column :customization_specs, :description, :string
  end
end
