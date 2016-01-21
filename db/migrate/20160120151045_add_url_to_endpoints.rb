class AddUrlToEndpoints < ActiveRecord::Migration
  def change
    add_column :endpoints, :url, :string
  end
end
