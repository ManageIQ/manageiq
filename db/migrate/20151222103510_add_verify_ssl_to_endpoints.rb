class AddVerifySslToEndpoints < ActiveRecord::Migration[4.2]
  def change
    add_column :endpoints, :verify_ssl, :integer
  end
end
