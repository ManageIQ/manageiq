class AddApiVersionAdnPathToEndpoint < ActiveRecord::Migration[5.0]
  def change
    add_column :endpoints, :api_version, :string
    add_column :endpoints, :path,        :string
  end
end
