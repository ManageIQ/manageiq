module MiqWebServerRunnerMixin
  extend ActiveSupport::Concern

  included do
    self.wait_for_worker_monitor = false
  end

  def do_work
  end

  def do_before_work_loop
    @worker.release_db_connection

    # Since puma/thin traps interrupts, log that we're going away and update our worker row
    at_exit { do_exit("Exit request received.") }
  end

  module ClassMethods
    def start_worker(*args)
      runner = self.new(*args)
      _log.info("URI: #{runner.worker.uri}")

      # Do all the SQL worker preparation in the main thread
      runner.prepare

      # The heartbeating will be done in a separate thread
      Thread.new { runner.run }

      runner.worker.class.configure_secret_token
      start_rails_server(runner.worker.rails_server_options)
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
end
