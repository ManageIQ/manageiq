class UpdateTenantDivisibleOnExistingRows < ActiveRecord::Migration
  class Tenant < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("marking root tenant divisible") do
      Tenant.where(:divisible => nil).update_all(:divisible => true)
    end
  end
end
