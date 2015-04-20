module MiqReport::Schedule
  extend ActiveSupport::Concern
  included do
    before_destroy :remove_associated_schedules
  end

  def remove_associated_schedules
    _log.info("Removing any schedules associated with report: #{self.id}")
    report_schedules = MiqSchedule.where(:towhat => self.class.name)
    report_schedules.each do |sch|
      ids = sch.target_ids
      _log.info("Schedule id: #{sch.id}, targets: #{ids.inspect}")
      if ids == [self.id]
        _log.info("Removing Schedule id: #{sch.id}")
        sch.destroy
      end
    end
  end

end
