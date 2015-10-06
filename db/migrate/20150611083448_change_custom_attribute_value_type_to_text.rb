class ChangeCustomAttributeValueTypeToText < ActiveRecord::Migration
  def up
    change_column :custom_attributes, :value, :text
  end

  def down
    change_column :custom_attributes, :value, :string
  end
end
