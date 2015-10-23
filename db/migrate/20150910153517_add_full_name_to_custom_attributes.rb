class AddFullNameToCustomAttributes < ActiveRecord::Migration
  def change
    add_column :custom_attributes, :unique_name, :text
  end
end
