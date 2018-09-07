# Autoload ActionController::LogSubscriber to make sure it subscribes
# ActiveSupport::Notifications and generates a @queue_key for this thread and
# child threads (they will all be the same)
ActionController::LogSubscriber

class RailsRequestMonitor
  THREAD_VAR_KEY = "ActiveSupport::SubscriberQueueRegistry".freeze
  QUEUE_KEY      = ActiveSupport::Subscriber.subscribers.detect { |sub| 
                     sub.kind_of? ActionController::LogSubscriber
                   }.instance_variable_get(:@queue_key).dup.freeze

  class << self
    def log_long_running_requests(with_backtrace = false)
      now = Time.now
      Thread.list.each do |thread|
        if thread[THREAD_VAR_KEY] && queue = thread[THREAD_VAR_KEY].get_queue(QUEUE_KEY)
          queue.each do |request|
            next unless request.time < too_slow

            duration = (now - request.time).to_f  # don't use event.duration, will mutate
            message  = "Long running http(s) request: "                                 \
                       "'#{request.payload[:controller]}##{request.payload[:action]}' " \
                       "handled by ##{Process.pid}:#{thread.object_id.to_s(16)}, "      \
                       "running for #{duration.round(2)} seconds"
            message << "\n#{thread.backtrace}" if with_backtrace

            Rails.logger.warn(message)
          end
        end
      end
    end

    private

    # TODO:  Maybe make this a setting?
    def too_slow
      10.seconds.ago
    end
  end
end
