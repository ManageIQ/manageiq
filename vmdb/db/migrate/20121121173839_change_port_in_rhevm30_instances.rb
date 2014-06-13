class ChangePortInRhevm30Instances < ActiveRecord::Migration
  DEFAULT_PORT_3_0  = 8443
  DEFAULT_PORT_3_1  =  443

  class ExtManagementSystem < ActiveRecord::Base
    self.inheritance_column = :_type_disabled    # disable STI
  end

  def up
    say_with_time("Changing Port for RHEVM 3.0 Management Systems") do
      # studiously ignoring rhevm 3.1 in this migration
      # rhevm 3.1 uses https/443 so defaulting to nil is fine
      t = ExtManagementSystem.arel_table
      ExtManagementSystem.
        where(:type => 'EmsRedhat', :port => nil).
        where(t[:api_version].eq(nil).or t[:api_version].matches('3.0%')).
        update_all(:port => DEFAULT_PORT_3_0)
    end
  end

  def down
  end
end
