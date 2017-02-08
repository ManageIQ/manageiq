class CreateTenant < ActiveRecord::Migration
  def change
    create_table :tenants do |t|
      t.string :domain
      t.string :subdomain
      t.string :company_name
      t.string :appliance_name

      t.string :login_text
      t.string   :logo_file_name
      t.string   :logo_content_type
      t.integer  :logo_file_size
      t.datetime :logo_updated_at
      t.string   :login_logo_file_name
      t.string   :login_logo_content_type
      t.integer  :login_logo_file_size
      t.datetime :login_logo_updated_at
    end

    add_index :tenants, :domain
    add_index :tenants, :subdomain
  end
end
