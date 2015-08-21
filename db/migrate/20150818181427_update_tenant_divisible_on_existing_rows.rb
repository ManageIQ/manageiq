class UpdateTenantDivisibleOnExistingRows < ActiveRecord::Migration
  def up
    Tenant.where(:divisible => nil).each { |t| t.update_attribute(:divisible, true) }
  end
end
