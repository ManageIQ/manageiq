class UpdateSystemSchedules < ActiveRecord::Migration
  class MiqSchedule < ActiveRecord::Base; end

  def self.up
    say_with_time("Update system MiqSchedule") do
      MiqSchedule.where(:towhat => 'MiqReport').update_all(:prod_default => 'system')
    end
  end

  def self.down
  end
end
