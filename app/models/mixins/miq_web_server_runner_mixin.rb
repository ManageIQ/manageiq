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
end
