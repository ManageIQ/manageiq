module Vmdb
  module ConsoleMethods
    def enable_console_sql_logging
      ActiveRecord::Base.logger.level = 0
    end

    def disable_console_sql_logging
      ActiveRecord::Base.logger.level = 1
    end

    def toggle_console_sql_logging
      ActiveRecord::Base.logger.level == 0 ? disable_console_sql_logging : enable_console_sql_logging
    end

    # Development helper method for Rails console for simulating queue workers.
    def simulate_queue_worker(break_on_complete = false)
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?
      loop do
        q = MiqQueue.order(:id).first
        if q
          status, message, result = q.deliver
          q.delivered(status, message, result) unless status == MiqQueue::STATUS_RETRY
        else
          break_on_complete ? break : sleep(1.second)
        end
      end
    end
  end
end