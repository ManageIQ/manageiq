class AddDivisibleToTenants < ActiveRecord::Migration
  def change
    add_column  :tenants, :divisible, :boolean
  end
end
