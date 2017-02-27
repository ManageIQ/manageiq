class AddOptionsColumnToAuthentication < ActiveRecord::Migration[5.0]
  def change
    add_column :authentications, :options, :text
  end
end
