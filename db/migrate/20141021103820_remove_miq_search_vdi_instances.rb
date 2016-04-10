class RemoveMiqSearchVdiInstances < ActiveRecord::Migration
  class MiqSearch < ActiveRecord::Base; end

  def up
    say_with_time("Removing VDI User references from MiqSearch") do
      MiqSearch.where(:db => 'VdiUser').destroy_all
    end
  end
end
