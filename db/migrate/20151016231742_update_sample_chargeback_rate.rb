class UpdateSampleChargebackRate < ActiveRecord::Migration
  class ChargebackRate < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Update ChargebackRate description to 'Sample'") do
      ChargebackRate.where(:default => true).update_all(:description => "Sample")
    end
  end

  def down
    say_with_time("Update ChargebackRate description to 'Default'") do
      ChargebackRate.where(:default => true).update_all(:description => "Default")
    end
  end
end
