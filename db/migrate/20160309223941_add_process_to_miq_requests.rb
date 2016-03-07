class AddProcessToMiqRequests < ActiveRecord::Migration[5.0]
  class MiqRequest < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    add_column :miq_requests, :process, :boolean
    say_with_time("Update process attribute") do
      MiqRequest.update_all(:process => true)
    end
  end

  def down
    remove_column :miq_requests, :process
  end
end
