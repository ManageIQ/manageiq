class CreateTenant < ActiveRecord::Migration
  def change
    create_table :tenants do |t|
      t.string :domain
      t.string :subdomain
      t.string :company_name
      t.string :appliance_name

      t.string :login_text
      t.attachment :logo
      t.attachment :login_logo
    end

    add_index :tenants, :domain
    add_index :tenants, :subdomain
  end
end
