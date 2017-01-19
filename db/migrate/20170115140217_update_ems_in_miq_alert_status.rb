class UpdateEmsInMiqAlertStatus < ActiveRecord::Migration[5.0]
  class MiqAlertStatus < ActiveRecord::Base; end

  def up
    say_with_time("update ems_id in miq alert statuses") do
      %w(vms hosts ems_clusters container_images).each do |alert_resource|
        arel_table = Arel::Table.new(alert_resource.to_sym)
        klass_name = alert_resource.classify
        klass_name = 'VmOrTemplate' if alert_resource == 'vms'
        join_sql = arel_table.project(arel_table[:ems_id])
                             .where(arel_table[:id].eq(MiqAlertStatus.arel_table[:resource_id])).to_sql
        MiqAlertStatus.where(:resource_type => klass_name).update_all("ems_id = (#{join_sql})")
      end
    end
  end
end
