module Vmdb::ConsoleMethods
  module SimulateQueueWorker
    # Development helper method for Rails console for simulating queue workers.
    def simulate_queue_worker(break_on_complete: false, quiet_polling: true)
      raise NotImplementedError, "not implemented in production mode" if Rails.env.production?

      deliver_on = MiqQueue.arel_table[:deliver_on]

      stale_entries = MiqQueue.where(:state => MiqQueue::STATE_DEQUEUE).count
      puts "NOTE: there are #{stale_entries} entries on the queue that are in progress" if stale_entries > 0

      future_entries = MiqQueue.where(deliver_on.gt(1.minute.from_now)).count
      puts "NOTE: there are #{future_entries} entries in the future" if future_entries > 0

      loop do
        q = with_console_sql_logging_level(quiet_polling ? 1 : ActiveRecord::Base.logger.level) do
          MiqQueue.where.not(:state => MiqQueue::STATE_DEQUEUE)
                  .where(deliver_on.eq(nil).or(deliver_on.lteq(Time.now.utc)))
                  .where.not(:queue_name => "miq_server")
                  .order(:priority, :id)
                  .first
        end
        if q
          begin
            q.update!(:state => MiqQueue::STATE_DEQUEUE, :handler => MiqServer.my_server)
          rescue ActiveRecord::StaleObjectError
          else
            puts "\e[33;1m\n** Delivering #{MiqQueue.format_full_log_msg(q)}\n\e[0;m"
            q.deliver_and_process
          end
        else
          break_on_complete ? break : sleep(1.second)
        end
        break if break_on_complete.kind_of?(Integer) && (break_on_complete -= 1) <= 0
      end
    end
  end
end
