class AddServiceAccountToAuthentication < ActiveRecord::Migration[4.2]
  def change
    add_column :authentications, :service_account, :string
  end
end
