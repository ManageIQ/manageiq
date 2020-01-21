class NoFreePortError < StandardError; end

module MiqWebServerWorkerMixin
  extend ActiveSupport::Concern

  BINDING_ADDRESS = ENV['BINDING_ADDRESS'] || (Rails.env.production? ? "127.0.0.1" : "0.0.0.0")

  included do
    class << self
      attr_accessor :registered_ports
    end

    try(:maximum_workers_count=, 10)
  end

  module ClassMethods
    def binding_address
      BINDING_ADDRESS
    end

    def preload_for_console
      configure_secret_token(SecureRandom.hex(64))
    end

    def preload_for_worker_role
      raise "Expected database to be seeded via `rake db:seed`." unless EvmDatabase.seeded_primordially?
      configure_secret_token
    end

    def configure_secret_token(token = MiqDatabase.first.session_secret_token)
      return if Rails.application.config.secret_key_base

      Rails.application.config.secret_key_base = token

      # To set a secret token after the Rails.application is initialized,
      # we need to reset the secrets since they are cached:
      # https://github.com/rails/rails/blob/4-2-stable/railties/lib/rails/application.rb#L386-L401
      Rails.application.secrets = nil
    end

    def rails_server
      "puma"
    end

    def all_ports_in_use
      server_scope.select(&:enabled_or_running?).collect(&:port)
    end

    def build_uri(port)
      URI::HTTP.build(:host => binding_address, :port => port).to_s
    end

    def sync_workers
      # TODO: add an at_exit to remove all registered ports and gracefully stop apache
      self.registered_ports ||= []

      workers = find_current_or_starting
      current = workers.length
      desired = self.workers
      result  = {:adds => [], :deletes => []}
      ports = all_ports_in_use

      # TODO: This tracking of adds/deletes of pids and ports is not DRY
      ports_hash = {:deletes => [], :adds => []}

      if current != desired
        _log.info("Workers are being synchronized: Current #: [#{current}], Desired #: [#{desired}]")

        if desired > current && enough_resource_to_start_worker?
          (desired - current).times do
            port = reserve_port(ports)
            _log.info("Reserved port=#{port}, Current ports in use: #{ports.inspect}")
            ports << port
            ports_hash[:adds] << port
            w = start_worker(:uri => build_uri(port))
            result[:adds] << w.pid
          end
        elsif desired < current
          workers = workers.to_a
          (current - desired).times do
            w = workers.pop
            port = w.port
            ports.delete(port)
            ports_hash[:deletes] << port

            _log.info("Unreserved port=#{port}, Current ports in use: #{ports.inspect}")
            result[:deletes] << w.pid
            w.stop
          end
        end
      end

      result
    end

    def pid_file(port)
      Rails.root.join("tmp/pids/rails_server.#{port}.pid")
    end

    def port_range
      self::STARTING_PORT...(self::STARTING_PORT + maximum_workers_count)
    end

    def reserve_port(ports)
      free_ports = port_range.to_a - ports
      raise NoFreePortError if free_ports.empty?
      free_ports.first
    end
  end

  def pid_file
    @pid_file ||= self.class.pid_file(port)
  end

  def rails_server_options
    # See Rack::Server options which is what Rails::Server uses:
    # https://github.com/rack/rack/blob/1.6.4/lib/rack/server.rb#L152-L183
    params = {
      :Host        => self.class.binding_address,
      :environment => Rails.env.to_s,
      :app         => rails_application,
      :server      => self.class.rails_server
    }

    params[:Port] = port.kind_of?(Numeric) ? port : ENV["PORT"] || 3000
    params[:pid]  = self.class.pid_file(params[:Port]).to_s

    params
  end

  def rails_application
    @app ||= defined?(self.class::RACK_APPLICATION) ? self.class::RACK_APPLICATION.new : Rails.application
  end

  def start
    delete_pid_file
    super
  end

  def kill
    deleted_worker = super
    delete_pid_file
    deleted_worker
  end

  def delete_pid_file
    File.delete(pid_file) if File.exist?(pid_file)
  end

  def port
    @port ||= uri.blank? ? nil : URI.parse(uri).port
  end

  def release_db_connection
    self.update_spid!(nil)
    self.class.release_db_connection
  end
end
