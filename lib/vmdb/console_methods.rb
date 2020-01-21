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

    def with_console_sql_logging_level(level)
      old_level = ActiveRecord::Base.logger.level
      ActiveRecord::Base.logger.level = level
      yield
    ensure
      ActiveRecord::Base.logger.level = old_level
    end

    def backtrace(include_external = false)
      caller.select { |path| include_external || path.start_with?(Rails.root.to_s) }
    end

    # Development helper method for Rails console for simulating queue workers.
    def simulate_queue_worker(break_on_complete: false, quiet_polling: true)
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?
      loop do
        q = with_console_sql_logging_level(quiet_polling ? 1 : ActiveRecord::Base.logger.level) do
          MiqQueue.where(MiqQueue.arel_table[:queue_name].not_eq("miq_server")).order(:id).first
        end
        if q
          puts "\e[33;1m\n** Delivering #{MiqQueue.format_full_log_msg(q)}\n\e[0;m"
          status, message, result = q.deliver
          q.delivered(status, message, result) unless status == MiqQueue::STATUS_RETRY
        else
          break_on_complete ? break : sleep(1.second)
        end
        break if break_on_complete.kind_of?(Integer) && (break_on_complete -= 1) <= 0
      end
    end

    # Helper method to set up a $evm variable for debugging purposes in Rails console
    def automate_initialize_evm(user: nil)
      ws = MiqAeEngine::MiqAeWorkspaceRuntime.current = MiqAeEngine::MiqAeWorkspaceRuntime.new
      ws.ae_user = (user || User.find_by(:userid => 'admin'))
      $evm = MiqAeMethodService::MiqAeService.new(ws)
    end
  end
end
