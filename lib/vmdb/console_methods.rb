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

    def backtrace(include_external = false)
      caller.select { |path| include_external || path.start_with?(Rails.root.to_s) }
    end

    # Development helper method for Rails console for simulating queue workers.
    def simulate_queue_worker(break_on_complete = false)
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?
      Rails.logger.level = Logger::DEBUG
      loop do
        q = MiqQueue.where(MiqQueue.arel_table[:queue_name].not_eq("miq_server")).order(:id).first
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
