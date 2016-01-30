class AddVerifySslToEndpoints < ActiveRecord::Migration
  def change
    add_column :endpoints, :verify_ssl, :integer
  end
end
