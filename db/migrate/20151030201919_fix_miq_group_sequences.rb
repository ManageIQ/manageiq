class FixMiqGroupSequences < ActiveRecord::Migration
  class MiqGroup < ActiveRecord::Base; end

  def up
    say_with_time("Update MiqGroup missing sequences") do
      MiqGroup.where(:sequence => nil).update_all(:sequence => 1)
    end

    say_with_time("Update MiqGroup missing guids") do
      MiqGroup.where(:guid => nil).each do |g|
        g.update_attributes(:guid => MiqUUID.new_guid)
      end
    end
  end
end
