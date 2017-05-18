class ChangeCustomAttributeValueTypeToText < ActiveRecord::Migration[4.2]
  def up
    change_column :custom_attributes, :value, :text
  end

  def down
    change_column :custom_attributes, :value, :string
  end
end
