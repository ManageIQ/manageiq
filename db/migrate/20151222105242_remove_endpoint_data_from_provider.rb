class RemoveEndpointDataFromProvider < ActiveRecord::Migration
  def up
    remove_column :providers, :verify_ssl
  end

  def down
    add_column :providers, :verify_ssl, :integer
  end
end
