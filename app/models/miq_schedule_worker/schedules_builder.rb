class MiqScheduleWorker::SchedulesBuilder
  include Vmdb::Logging

  attr_reader :schedules

  def initialize(scheduler, schedule_category = nil)
    @scheduler = scheduler
    @schedule_category = schedule_category
    @schedules = []
  end

  def cron(schedule, opts = {}, &block)
    opts[:tags] ||= []
    opts[:tags].unshift(schedule_category) if schedule_category
    opts[:job] ||= true
    schedules << scheduler.cron(schedule, opts, &block)
  end

  def schedule_every(duration, opts = {}, &block)
    raise ArgumentError if duration.nil?
    opts[:tags] ||= []
    opts[:tags].unshift(schedule_category) if schedule_category
    schedules << scheduler.schedule_every(duration, opts, &block)
  rescue ArgumentError => err
    _log.error("#{err.class} for schedule_every with #{[duration, opts].inspect}.  Called from: #{caller[1]}.")
  end

  private

  attr_reader :scheduler, :schedule_category
end
