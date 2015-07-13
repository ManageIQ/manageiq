class AddCsrfSecretTokenToMiqDatabase < ActiveRecord::Migration
  def change
    add_column :miq_databases, :csrf_secret_token, :string
  end
end
