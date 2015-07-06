class SetDefaultForPxeServerCustomizationDirectory < ActiveRecord::Migration
  class PxeServer < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Seting default value for PxeServer #customization_directory") do
      PxeServer.where(:customization_directory => nil).update_all(:customization_directory => "")
    end
  end
end
