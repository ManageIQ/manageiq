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

    def schedule_every(name, duration = nil, opts = {}, &block)
      log_schedule(name, opts.merge(:duration => duration))

      if duration.blank?
        logger.warn("Duration is empty, scheduling ignored. Called from: #{caller(2..2).first}.")
        return
      end

      role_schedule << rufus_scheduler.schedule_every(duration, nil, opts, &block)
    rescue ArgumentError => err
      logger.error("#{err.class} for schedule_every with [#{duration}, #{opts.inspect}].  Called from: #{caller(2..2).first}.")
    end

    def schedule_cron(name, cronline, opts = {}, &block)
      log_schedule(name, opts.merge(:cronline => cronline))

      role_schedule << rufus_scheduler.schedule_cron(cronline, nil, opts, &block)
    end

    private def log_schedule(name, opts)
      opts_message = opts.slice(:duration, :cronline, :first_at, :first_in).map { |k, v| "#{k}: #{v.inspect}" }.join(", ")
      logger.info("Scheduling #{name} - #{opts_message}")
    end
  end
end
