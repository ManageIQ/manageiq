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
      worker = self.new(*args)
      _log.info("URI: #{worker.worker.uri}")

      # Do all the SQL worker preparation in the main thread
      worker.prepare

      # TODO: Need to rename build_command_line to options_hash or something
      options = corresponding_model.build_command_line(:Port => args.first[:Port])

      # The heartbeating will be done in a separate thread
      Thread.new { worker.run }

      start_rails_server(options)
    end

    def start_rails_server(options)
      require "rails/commands/server"

      _log.info("With options: #{options.inspect}")
      Rails::Server.new(options).tap do |server|
        # Use the already created Vmdb::Application, don't use a new one
        # as it will require configuring the session store/secret and ???
        # TODO: There has to be a way to create a Rails::Server with an existing Rails::Application.
        server.instance_variable_set(:@app, Vmdb::Application)
        Dir.chdir(Vmdb::Application.root)
        server.start
      end
    end
  end
end
