class ClearTenantSeed < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
  end

  def up
    Tenant.update_all(:name => nil)
  end
end
