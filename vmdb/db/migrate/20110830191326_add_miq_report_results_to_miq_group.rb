class AddMiqReportResultsToMiqGroup < ActiveRecord::Migration
  class MiqReportResult < ActiveRecord::Base; end
  class User            < ActiveRecord::Base; end

  def self.up
    change_table :miq_report_results do |t|
      t.belongs_to  :miq_group
    end

    say_with_time("Setting MiqReportResult miq_group_id to User's group") do
      MiqReportResult.all.each do |rr|
        user_info = rr.userid.to_s.split('|')
        if user_info.length == 1
          user = User.find_by_userid(user_info.first)
          rr.update_attribute(:miq_group_id, user.miq_group_id) unless user.nil?
        end
      end
    end
  end

  def self.down
    change_table :miq_report_results do |t|
      t.remove_belongs_to  :miq_group
    end
  end
end
