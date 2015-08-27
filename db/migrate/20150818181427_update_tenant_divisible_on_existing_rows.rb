class UpdateTenantDivisibleOnExistingRows < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
  end

  def up
    Tenant.where(:divisible => nil).update_all(:divisible => true)
  end
end
