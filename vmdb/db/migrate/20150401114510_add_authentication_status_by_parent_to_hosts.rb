class AddAuthenticationStatusByParentToHosts < ActiveRecord::Migration
  def change
    add_column :hosts, :authentication_status_by_parent, :string
  end
end
