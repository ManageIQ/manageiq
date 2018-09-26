module MiqWebServerRunnerMixin
  extend ActiveSupport::Concern

  def do_work
  end

  def do_before_work_loop
    @worker.release_db_connection

    # Since puma traps interrupts, log that we're going away and update our worker row
    at_exit { do_exit("Exit request received.") }
  end

  def start
    _log.info("URI: #{worker.uri}")

    # Do all the SQL worker preparation in the main thread
    prepare

    # The heartbeating will be done in a separate thread
    Thread.new { run }

    worker.class.configure_secret_token
    start_rails_server(worker.rails_server_options)
  end

  def start_rails_server(options)
    require "rails/commands/server"

    _log.info("With options: #{options.except(:app).inspect}")
    Rails::Server.new(options).tap do |server|
      Dir.chdir(Vmdb::Application.root)
      server.start
    end
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
