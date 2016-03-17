class ClearTenantSeed < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base; end

  def up
    say_with_time("Setting root tenant to default to settings") do
      Tenant.update_all(:name => nil)
    end
  end
end
