module MiqReport::Schedule
  extend ActiveSupport::Concern
  included do
    before_destroy :remove_associated_schedules
  end

  def remove_associated_schedules
    $log.info("MIQ(MiqReport.remove_associated_schedules) Removing any schedules associated with report: #{self.id}")
    report_schedules = MiqSchedule.where(:towhat => self.class.name)
    report_schedules.each do |sch|
      ids = sch.target_ids
      $log.info("MIQ(MiqReport.remove_associated_schedules) Schedule id: #{sch.id}, targets: #{ids.inspect}")
      if ids == [self.id]
        $log.info("MIQ(MiqReport.remove_associated_schedules) Removing Schedule id: #{sch.id}")
        sch.destroy
      end
    end
  end

end
