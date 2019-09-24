class MiqScheduleWorker
  class Scheduler
    # the logger
    attr_accessor :logger
    # the scheduler used to create the jobs. (i.e.: @system_scheduler)
    attr_accessor :rufus_scheduler
    # list of schedules for a particular role (i.e.: @schedules[:all])
    attr_accessor :role_schedule

    def initialize(logger, role_schedule, rufus_scheduler)
      @logger          = logger
      @role_schedule   = role_schedule
      @rufus_scheduler = rufus_scheduler
    end

    def schedule_every(duration = nil, callable = nil, opts = {}, &block)
      if duration.blank?
        logger.warn("Duration is empty, scheduling ignored. Called from: #{block}.")
        return
      end

      role_schedule << rufus_scheduler.schedule_every(duration, callable, opts, &block)
    rescue ArgumentError => err
      logger.error("#{err.class} for schedule_every with [#{duration}, #{opts.inspect}].  Called from: #{caller[1]}.")
    end
    alias every schedule_every

    def schedule_cron(cronline, callable = nil, opts = {}, &block)
      role_schedule << rufus_scheduler.schedule_cron(cronline, callable, opts, &block)
    end
  end
end
