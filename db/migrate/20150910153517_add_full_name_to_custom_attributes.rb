class AddFullNameToCustomAttributes < ActiveRecord::Migration[4.2]
  def change
    add_column :custom_attributes, :unique_name, :text
  end
end
