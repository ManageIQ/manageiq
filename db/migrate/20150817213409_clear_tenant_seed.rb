class ClearTenantSeed < ActiveRecord::Migration
  def up
    execute "update tenants set name = null"
  end
end
