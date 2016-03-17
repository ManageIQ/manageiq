class UpdateSwitchUidEms < ActiveRecord::Migration[5.0]
  class Switch < ActiveRecord::Base
  end

  def up
    say_with_time("Updating switch uid_ems to be prefixed with host_id") do
      Switch.all.each do |s|
        s.update(:uid_ems => "#{s.host_id}|#{s.uid_ems}")
      end
    end
  end

  def down
    Switch.all.each do |s|
      fail "Expected '|' not found in uid_ems" if s.uid_ems.index('|').nil?
      s.update(:uid_ems => s.uid_ems[s.uid_ems.index('|')+1..-1])
    end
  end
end
