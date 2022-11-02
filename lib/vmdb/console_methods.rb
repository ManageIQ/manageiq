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

    def set_translation_locale(locale = "en")
      I18n.locale = locale
    end

    def set_user_translation_locale(userid: "admin", locale: "en")
      user = User.find_by_userid(userid)

      user.settings[:display] = {:locale => locale}
      user.save!

      User.current_user = user
      set_translation_locale(user.settings[:display][:locale])
    end

    # Development helper method for Rails console for simulating queue workers.
    def simulate_queue_worker(break_on_complete: false, quiet_polling: true)
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?
      deliver_on = MiqQueue.arel_table[:deliver_on]
      loop do
        q = with_console_sql_logging_level(quiet_polling ? 1 : ActiveRecord::Base.logger.level) do
          MiqQueue.where(deliver_on.eq(nil).or(deliver_on.lteq(Time.now.utc)))
                  .where.not(:queue_name => "miq_server").order(:id).first
        end
        if q
          puts "\e[33;1m\n** Delivering #{MiqQueue.format_full_log_msg(q)}\n\e[0;m"
          q.update!(:state => MiqQueue::STATE_DEQUEUE, :handler => MiqServer.my_server)
          q.deliver_and_process
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
