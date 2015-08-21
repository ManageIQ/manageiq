class UpdateTenantDivisibleOnExistingRows < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
  end
  def up
    Tenant.where(:divisible => nil).each { |t| t.update_attribute(:divisible, true) }
  end
end
