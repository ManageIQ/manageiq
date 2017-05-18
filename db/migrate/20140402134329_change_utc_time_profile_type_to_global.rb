class ChangeUtcTimeProfileTypeToGlobal < ActiveRecord::Migration[4.2]
  class TimeProfile < ActiveRecord::Base; end

  def up
    say_with_time("Change Default UTC Time Profile to Type Global") do
      TimeProfile.all.each do |tp|
        if tp.profile_type.nil?
          tp.profile_type = "global"
          tp.save
        end
      end
    end
  end
end
