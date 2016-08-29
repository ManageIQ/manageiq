class FixPortZeroOnEnpoints < ActiveRecord::Migration[5.0]
  # the problem was in that migration 20141121200153_migrate_ems_attributes_to_endpoints.rb
  # here port got converted from a string to int, but "".to_i is 0.
  class Endpoint < ActiveRecord::Base
  end

  def up
    say_with_time("Fixing ports 0 in Endpoint") do
      Endpoint.where(:port => 0).update_all(:port => nil)
    end
  end

  def down
    # irreversible, sorry
  end
end
