class UpdateDescriptionInMiqAlertStatus < ActiveRecord::Migration[5.0]
  class MiqAlertStatus < ActiveRecord::Base
    belongs_to :miq_alert, :class_name => "UpdateDescriptionInMiqAlertStatus::MiqAlert"
  end

  class MiqAlert < ActiveRecord::Base
    has_many :miq_alert_statuses, :dependent => :destroy, :class_name => "UpdateDescriptionInMiqAlertStatus::MiqAlertStatus"
  end

  def up
    say_with_time("update description in miq alert statuses") do
      miq_alerts = Arel::Table.new('miq_alerts')
      miq_alert_statuses = Arel::Table.new('miq_alert_statuses')
      join_sql = miq_alerts.project(miq_alerts[:description])
                           .where(miq_alerts[:id].eq(miq_alert_statuses[:miq_alert_id])).to_sql
      MiqAlertStatus.update_all("description = (#{join_sql})")
    end
  end
end
