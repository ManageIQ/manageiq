class AddCertificateAuthorityToEndpoint < ActiveRecord::Migration[5.0]
  def change
    add_column :endpoints, :certificate_authority, :text
  end
end
