require 'manageiq'
require 'util/vmdb-logger'

module Vmdb
  def self.logger
    $log
  end

  def self.rails_logger
    $rails_log
  end

  module Loggers
    module Instrument
      # To be used as Excon's request logger, the logger must respond to
      #   #instrument as in ActiveSupport::Notifications.
      #   Implementation derived from Excon::StandardInstrumentor
      def instrument(name, params = {})
        method, message =
          case name
          when "excon.request" then  [:debug, message_for_excon_request(params)]
          when "excon.response" then [:debug, message_for_excon_response(params)]
          when "excon.error" then    [:debug, message_for_excon_error(params)]
          else                   [:debug, message_for_other(params)]
          end

        send(method, "#{name.ljust(14)}  #{message}")
        yield if block_given?
      end

      private

      def message_for_excon_request(params)
        uri_parts    = params.values_at(:scheme, nil, :host, :port, nil, :path, nil, nil, nil)
        uri_parts[3] = uri_parts[3].to_i if uri_parts[3] # port
        uri          = {:uri => URI::Generic.build(uri_parts).to_s}
        log_params(uri.merge!(params.slice(:query, :method, :headers, :body).delete_nils))
      end

      def message_for_excon_response(params)
        log_params(params.slice(:status, :headers, :body))
      end

      def message_for_excon_error(params)
        params[:error].pretty_inspect
      end

      def message_for_other(params)
        log_params(params.except(:instrumentor, :instrumentor_name, :connection, :stack, :middlewares))
      end

      def log_params(params)
        sanitized = sanitize_params(params)
        sanitized[:body] = parse_body(sanitized[:body])
        "\n#{sanitized.pretty_inspect}"
      end

      def parse_body(body)
        JSON.parse(body) if body
      rescue JSON::ParserError
        body
      end

      def sanitize_params(params)
        if params.key?(:headers) && params[:headers].key?('Authorization')
          params[:headers] = params[:headers].dup
          params[:headers]['Authorization'] = "********"
        end
        if params.key?(:password)
          params[:password] = "********"
        end
        if params.key?(:body)
          params[:body] = params[:body].to_s.gsub(/"password":".+?"\}/, '"password":"********"}')
        end
        params
      end
    end

    def self.init
      return if @initialized
      create_loggers
      @initialized = true
    end

    def self.apply_config(config)
      apply_config_value(config, $log,               :level)
      apply_config_value(config, $rails_log,         :level_rails)
      apply_config_value(config, $vim_log,           :level_vim)
      apply_config_value(config, $rhevm_log,         :level_rhevm)
      apply_config_value(config, $aws_log,           :level_aws)
      apply_config_value(config, $kube_log,          :level_kube)
      apply_config_value(config, $datawarehouse_log, :level_datawarehouse)
      apply_config_value(config, $cn_monitoring_log, :level_cn_monitoring)
      apply_config_value(config, $scvmm_log,         :level_scvmm)
      apply_config_value(config, $api_log,           :level_api)
      apply_config_value(config, $fog_log,           :level_fog)
      apply_config_value(config, $azure_log,         :level_azure)
      apply_config_value(config, $lenovo_log,        :level_lenovo)
      apply_config_value(config, $websocket_log,     :level_websocket)
      apply_config_value(config, $vcloud_log,        :level_vcloud)
      apply_config_value(config, $nuage_log,         :level_nuage)
    end

    def self.create_loggers
      path_dir = ManageIQ.root.join("log")

      $audit_log         = AuditLogger.new(path_dir.join("audit.log"))
      $container_log     = ContainerLogger.new
      $log               = create_multicast_logger(path_dir.join("evm.log"))
      $rails_log         = create_multicast_logger(path_dir.join("#{Rails.env}.log"))
      $fog_log           = create_multicast_logger(path_dir.join("fog.log"), FogLogger)
      $policy_log        = create_multicast_logger(path_dir.join("policy.log"))
      $vim_log           = create_multicast_logger(path_dir.join("vim.log"))
      $rhevm_log         = create_multicast_logger(path_dir.join("rhevm.log"))
      $aws_log           = create_multicast_logger(path_dir.join("aws.log"))
      $lenovo_log        = create_multicast_logger(path_dir.join("lenovo.log"))
      $kube_log          = create_multicast_logger(path_dir.join("kubernetes.log"))
      $datawarehouse_log = create_multicast_logger(path_dir.join("datawarehouse.log"))
      $cn_monitoring_log = create_multicast_logger(path_dir.join("container_monitoring.log"))
      $scvmm_log         = create_multicast_logger(path_dir.join("scvmm.log"))
      $azure_log         = create_multicast_logger(path_dir.join("azure.log"))
      $api_log           = create_multicast_logger(path_dir.join("api.log"))
      $websocket_log     = create_multicast_logger(path_dir.join("websocket.log"))
      $miq_ae_logger     = create_multicast_logger(path_dir.join("automation.log"))
      $vcloud_log        = create_multicast_logger(path_dir.join("vcloud.log"))
      $nuage_log         = create_multicast_logger(path_dir.join("nuage.log"))

      configure_external_loggers
    end
    private_class_method :create_loggers

    def self.create_multicast_logger(log_file_path, logger_class = VMDBLogger)
      logger_instance = logger_class.new(log_file_path).tap do |logger|
        logger.level = Logger::DEBUG
      end
      MulticastLogger.new(logger_instance).tap do |l|
        l.loggers << $container_log if ENV["CONTAINER"]
      end
    end
    private_class_method :create_multicast_logger

    def self.configure_external_loggers
      require 'awesome_spawn'
      AwesomeSpawn.logger = $log

      require 'log_decorator'
      LogDecorator.logger = $log
    end
    private_class_method :configure_external_loggers


    def self.apply_config_value(config, logger, key)
      old_level      = logger.level
      new_level_name = (config[key] || "INFO").to_s.upcase
      new_level      = VMDBLogger.const_get(new_level_name)
      if old_level != new_level
        $log.info("MIQ(#{name}.apply_config) Log level for #{File.basename(logger.filename)} has been changed to [#{new_level_name}]")
        logger.level = new_level
      end
    end
    private_class_method :apply_config_value
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "loggers", "*")).each { |f| require f }
