class AddDivisibleToTenants < ActiveRecord::Migration[4.2]
  def change
    add_column  :tenants, :divisible, :boolean
  end
end
