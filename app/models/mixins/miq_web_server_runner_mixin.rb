module MiqWebServerRunnerMixin
  extend ActiveSupport::Concern

  def do_work
  end

  def do_before_work_loop
    @worker.release_db_connection
  end

  def run
    # The heartbeating will be done in a separate thread
    worker_thread = Thread.new { super }

    worker.class.configure_secret_token
    start_rails_server(worker.rails_server_options)

    # when puma exits allow the heartbeat thread to exit cleanly using #do_exit
    worker_thread.join
  end

  def start_rails_server(options)
    require 'rails/command'
    require 'rails/commands/server/server_command'

    _log.info("With options: #{options.except(:app).inspect}")
    Rails::Server.new(options).tap do |server|
      Dir.chdir(Vmdb::Application.root)
      server.start
    end
  rescue SignalException => e
    raise unless MiqWorker::Runner::INTERRUPT_SIGNALS.include?(e.message)
  ensure
    @worker_should_exit = true
  end

  def do_heartbeat_work
    log_long_running_requests
  end

  CHECK_LONG_RUNNING_REQUESTS_INTERVAL = 30.seconds
  def log_long_running_requests
    @last_checked_hung_requests ||= Time.now.utc
    return if @last_checked_hung_requests > CHECK_LONG_RUNNING_REQUESTS_INTERVAL.ago

    RequestStartedOnMiddleware.long_running_requests.each do |request, duration, thread|
      message = "Long running http(s) request: '#{request}' handled by ##{Process.pid}:#{thread.object_id.to_s(16)}, running for #{duration.round(2)} seconds"
      _log.warn(message)
      Rails.logger.warn(message)
    end

    @last_checked_hung_requests = Time.now.utc
  end
end
