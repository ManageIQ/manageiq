class RemoveEndpointDataFromProvider < ActiveRecord::Migration[4.2]
  def up
    remove_column :providers, :verify_ssl
  end

  def down
    add_column :providers, :verify_ssl, :integer
  end
end
