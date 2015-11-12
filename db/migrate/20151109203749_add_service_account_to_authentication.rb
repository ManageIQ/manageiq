class AddServiceAccountToAuthentication < ActiveRecord::Migration
  def change
    add_column :authentications, :service_account, :string
  end
end
