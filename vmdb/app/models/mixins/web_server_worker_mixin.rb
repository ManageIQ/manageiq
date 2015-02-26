require 'miq_apache'
module WebServerWorkerMixin
  extend ActiveSupport::Concern

  BINDING_ADDRESS = Rails.env.production? ? "127.0.0.1" : "0.0.0.0"

  included do
    class << self
      attr_accessor :registered_ports
    end

    def self.binding_address
      BINDING_ADDRESS
    end

    def self.rails_server_command_line
      @rails_server_command_line ||= begin
        "#{self.nice_prefix} #{Rails.root.join("bin", "rails")} server".freeze
      end
    end

    def self.build_command_line(*params)
      params = params.first || {}

      defaults = {
        :port         => 3000,
        :binding      => binding_address,
        :environment  => Rails.env.to_s,
        :config       => Rails.root.join("config.ru")
      }

      params = defaults.merge(params)
      params[:pid]  = self.thin_pid_file(params[:port])

      # Usage: rails server [mongrel, thin, etc] [options]
      #      -p, --port=port                  Runs Rails on the specified port.
      #                                       Default: 3000
      #      -b, --binding=ip                 Binds Rails to the specified ip.
      #                                       Default: 0.0.0.0
      #      -c, --config=file                Use custom rackup configuration file
      #      -d, --daemon                     Make server run as a Daemon.
      #      -u, --debugger                   Enable ruby-debugging for the server.
      #      -e, --environment=name           Specifies the environment to run this server under (test/development/production).
      #                                       Default: development
      #      -P, --pid=pid                    Specifies the PID file.
      #                                       Default: tmp/pids/server.pid
      #
      #      -h, --help                       Show this help message.
      #
      cl = self.rails_server_command_line.dup

      params.each { |k, v| cl << " --#{k} \"#{v}\"" unless v.blank? }
      return cl
    end

    def self.all_ports_in_use
      self.server_scope.all.collect { |w| w.port unless w.is_stopped? && !MiqProcess.is_worker?(w.pid)}.compact
    end

    # Utilize URI::Generic#hostname to add support for IPv6 literals
    # TODO: simplify this once https://github.com/ruby/ruby/pull/765 lands in our ruby
    def self.build_uri(port)
      uri = URI::HTTP.build(:port => port)
      uri.hostname = binding_address
      uri.to_s
    end

    def self.sync_workers
      #TODO: add an at_exit to remove all registered ports and gracefully stop apache
      self.registered_ports ||= []

      workers = self.find_current_or_starting
      current = workers.length
      desired = self.has_required_role? ? self.workers : 0
      result  = { :adds => [], :deletes => [] }
      ports = self.all_ports_in_use

      if current != desired
        $log.info("MIQ(#{self.name}.sync_workers) Workers are being synchronized: Current #: [#{current}], Desired #: [#{desired}]")

        if desired > current && enough_resource_to_start_worker?
          (desired - current).times do
            port = self.reserve_port(ports)
            $log.info("MIQ(#{self.name}.sync_workers) Reserved port=#{port}, Current ports in use: #{ports.inspect}")
            ports << port
            w = self.start_worker(:uri => build_uri(port))
            result[:adds] << w.pid
          end
        elsif desired < current
          (current - desired).times do
            w = workers.pop
            port = w.port
            ports.delete(port)

            $log.info("MIQ(#{self.name}.sync_workers) Unreserved port=#{port}, Current ports in use: #{ports.inspect}")
            result[:deletes] << w.pid
            w.stop
          end
        end
      end

      self.modify_apache_ports(:adds => ports) if !ports.empty? && MiqEnvironment::Command.supports_apache?

      result
    end

    def self.thin_pid_file(port)
      Rails.root.join("tmp/pids/thin.#{port}.pid")
    end

    def thin_pid_file
      @thin_pid_file ||= self.class.thin_pid_file(self.port)
    end

    def self.install_apache_proxy_config
      options = {
        :member_file    => self::BALANCE_MEMBER_CONFIG_FILE,
        :redirects_file => self::REDIRECTS_CONFIG_FILE,
        :method         => self::LB_METHOD,
        :redirects      => self::REDIRECTS,
        :cluster        => self::CLUSTER,
      }

      $log.info("MIQ(#{self.name}.install_apache_proxy_config) [#{options.inspect}")
      MiqApache::Conf.install_default_config(options)
    end

    def self.modify_apache_ports(ports_hash)
      return unless MiqEnvironment::Command.supports_apache?
      adds    = Array(ports_hash[:adds])
      deletes = Array(ports_hash[:deletes])

      # Remove any already registered
      adds = adds - self.registered_ports

      return false if adds.empty? && deletes.empty?

      conf = MiqApache::Conf.instance(self::BALANCE_MEMBER_CONFIG_FILE)

      unless adds.empty?
        $log.info("MIQ(#{self.name}.modify_apache_ports) Adding port(s) #{adds.inspect}")
        conf.add_ports(adds)
      end

      unless deletes.empty?
        $log.info("MIQ(#{self.name}.modify_apache_ports) Removing port(s) #{deletes.inspect}")
        conf.remove_ports(deletes)
      end

      saved = conf.save
      if saved
        self.registered_ports += adds
        self.registered_ports -= deletes
        MiqServer.my_server.queue_restart_apache
        $log.info("MIQ(#{self.name}.modify_apache_ports) Added/removed port(s) #{adds.inspect}/#{deletes.inspect}, registered ports after #{self.registered_ports.inspect}")
      end
      return saved
    end

    def self.reserve_port(ports)
      index = 0
      loop do
        port = self::STARTING_PORT + index
        return port unless ports.include?(port)
        index = index + 1
      end
    end

    def command_line_params
      params = {}
      params[:port] = self.port if self.port.kind_of?(Numeric)
      params
    end

    def start
      pid_file = self.thin_pid_file
      File.delete(pid_file) if File.exist?(pid_file)
      ENV['PORT'] = self.port.to_s
      super
    end

    def terminate
      # HACK: Cannot call exit properly from UiWorker nor can we Process.kill('INT', ...) from inside the worker
      # Hence, this is an external mechanism for terminating this worker.
      log_prefix = "MIQ(#{self.class.name}.terminate)"

      begin
        $log.info("#{log_prefix} Terminating #{self.format_full_log_msg}, status [#{self.status}]")
        Process.kill("TERM", self.pid)
        # TODO: Variablize and clean up this 10-second-max loop of waiting on Worker to gracefully shut down
        10.times do
          unless MiqProcess.alive?(self.pid)
            self.update_attributes(:stopped_on => Time.now.utc, :status => MiqWorker::STATUS_STOPPED)
            break
          end
          sleep 1
        end
      rescue Errno::ESRCH
        $log.warn("#{log_prefix} #{self.format_full_log_msg} has been killed")
      rescue => err
        $log.warn("#{log_prefix} #{self.format_full_log_msg} has been killed, but with the following error: #{err}")
      end

      self.kill if MiqProcess.alive?(self.pid)
    end

    def kill
      pid_file       = self.thin_pid_file
      deleted_worker = super
      File.delete(pid_file) if File.exist?(pid_file)
      deleted_worker
    end

    def port
      @port ||= self.uri.blank? ? nil : URI.parse(self.uri).port
    end

    def release_db_connection
      self.update_spid!(nil)
      self.class.release_db_connection
    end

  end
end
