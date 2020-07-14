require "fileutils"

# A wrapper around the foreman utility for running ManageIQ in the integration
# environment, with either the server acting more "dev like" or "prod like"
# depending on the scenario (local development versus CI).
#
module ManageIQ
  module Integration
    class ForemanManager
      def self.pid_filename
        @pid_filename ||= Environment.tmp_dir.join('foreman.pid')
      end

      def self.log_file
        Rails.root.join("log", "integration.foreman.log")
      end

      def self.procfile
        @procfile ||= Environment.tmp_dir.join('Procfile')
      end

      def self.procfile_template_data
        require 'erb'
        template_path = File.expand_path('Procfile.example.erb', __dir__)

        if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(2.6)
          ERB.new(File.read(template_path), trim_mode: "-").result(binding)
        else
          ERB.new(File.read(template_path), nil, "-").result(binding)
        end
      end

      def self.extra_workers
        if (worker_string = ENV["FOREMAN_INTEGRATION_EXTRA_WORKERS"])
          worker_string.split(",")
        else
          []
        end
      end

      def self.setup
        FileUtils.mkdir_p(Environment.tmp_dir)
        FileUtils.rm_f(procfile)

        File.write(procfile, procfile_template_data)
      end

      def self.run
        if process_alive?
          warn "foreman process already running with pid: #{server_pid} from #{pid_filename}"
        elsif ui_ping
          ui_server_host = "#{Environment.ui_host}:#{Environment.ui_port}"
          warn <<~WARN
            Existing process for #{ui_server_host} exist already!  Cowardly refusing to kill it...

            Unless you "absolutely know what you are doing", make sure this
            environment is running in `integration` mode, or restart this test
            run after you have closed that server down so this task can execute
            an isolated process for you.  Otherwise test will likely fail due
            to missing resources that only exist in the integration ENV.

          WARN
        else
          foreman_cmd = %W[
            foreman start --port=3000
                          --root=#{Rails.root}
                          --procfile=#{procfile}
          ].join(" ")

          pid = Process.spawn(foreman_cmd, [:out, :err] => [log_file, "a"])
          Process.detach(pid)
          File.write(pid_filename, pid)
        end
      end

      def self.stop
        PidFile.new(pid_filename).terminate
      end

      # Simple status check:
      #
      # - Checks for existing pid file
      # - If the process is running
      # - If the UI is responding to a request
      #
      def self.status
        if server_pid
          puts "Server PID##{server_pid}: ".ljust(18) + (process_alive? ? "running" : "stopped")
        else
          puts "Server PID#NA:    PID file (#{pid_filename}) doesn't exist..."
        end
        puts "UI running?:      #{ui_ping}"
      end

      def self.process_alive?
        PidFile.new(pid_filename).running?
      end

      def self.server_pid
        PidFile.new(pid_filename).pid
      end

      def self.ui_ping
        require 'net/http'

        net_http = Net::HTTP.new(Environment.ui_host, Environment.ui_port)
        net_http.request_head(Environment.ui_ping_route).code == "200"
      rescue Errno::ECONNREFUSED
        false
      end

      def self.ui_running?
        ui_ready = false
        wait_num = ENV["CI"] ? 60 : 15

        wait_num.times do
          break if (ui_ready = ui_ping)

          sleep 2
        end

        unless ui_ready
          raise "ERR: UI server was not able to start or start properly" \
                " (after waiting ~#{wait_num * 2 / 60.0} minutes)"
        end
      rescue => err
        if ENV["CI"]
          stop
          sleep 5 # allow server to stop and flush logs

          debug_output_for_server_logs
          debug_server_boot
        end

        raise err
      end

      def self.debug_output_for_server_logs
        integration_log_file = Rails.root.join("log", "integration.log")
        evm_log_file         = Rails.root.join("log", "evm.log")

        puts <<~DEBUGGING_OUTPUT

          ***************************************************
          *     Printing Debugging log info for server:     *
          ***************************************************

          Procfile contents
          -----------------

          #{File.read(procfile)}


          last 100 lines of '#{log_file}':
          #{'-' * (21 + log_file.to_s.length)}

          #{tail_file(log_file)}


          last 100 lines of 'log/integration.log':
          ----------------------------------------

          #{tail_file(integration_log_file)}


          last 100 lines of 'log/evm.log':
          --------------------------------

          #{tail_file(evm_log_file)}


        DEBUGGING_OUTPUT
      end

      def self.debug_server_boot
        log_file  = Rails.root.join("log", "integration.debug.log")
        test_boot = "#{Gem.ruby} #{Environment.run_single_worker_bin} MiqUiWorker"
        pid       = Process.spawn(test_boot, [:out, :err] => [log_file, 'w'])

        puts "running inline ruby server to test for errors..."
        puts
        puts "  cmd: #{test_boot}"
        puts

        Timeout.timeout(30) { Process.waitpid(pid) }
      rescue Timeout::Error => e
        Process.kill("TERM", pid)
      ensure
        sleep 5 # give a few seconds for the logs output to flush to log_file

        puts File.read(log_file)
        puts
        puts
      end

      def self.tail_file(filename, num_lines = 100)
        require 'elif'

        line_buffer = []

        Elif.open(filename) do |log_io|
          num_lines.times do
            log_line = log_io.readline
            break if log_line.nil?
            line_buffer.unshift log_io.readline
          rescue EOFError
            # if we reach then end of a file, just end the loop
          end
        end

        # new lines are already included, so just convert to a string
        line_buffer.join
      end
    end
  end
end
