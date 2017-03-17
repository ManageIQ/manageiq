class CopyAgentIdToMiqServerIdInJobsTable < ActiveRecord::Migration[5.0]
  class Job < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("copying data from agent_id column to miq_server_id column on jobs table") do
      Job.update_all("miq_server_id = agent_id")
    end
  end

  def down
    say_with_time("nullifying miq_server_id column on jobs table") do
      Job.update_all(:miq_server_id => nil)
    end
  end
end
