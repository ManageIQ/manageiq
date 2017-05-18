class AddUrlToEndpoints < ActiveRecord::Migration[4.2]
  def change
    add_column :endpoints, :url, :string
  end
end
