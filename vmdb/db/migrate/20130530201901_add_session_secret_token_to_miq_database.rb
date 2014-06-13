class AddSessionSecretTokenToMiqDatabase < ActiveRecord::Migration
  def change
    add_column :miq_databases, :session_secret_token, :string
  end
end
