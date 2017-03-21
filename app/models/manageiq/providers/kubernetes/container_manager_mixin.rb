require 'openssl'
require 'MiqContainerGroup/MiqContainerGroup'

module ManageIQ::Providers::Kubernetes::ContainerManagerMixin
  extend ActiveSupport::Concern

  DEFAULT_PORT = 6443
  included do
    default_value_for :port do |provider|
      # port is not a column on this table, it's delegated to endpoint.
      # This may confuse `default_value_for` to apply when we do have a port;
      # checking `provider.port` first prevents this from overriding it.
      provider.port || provider.class::DEFAULT_PORT
    end
  end

  module ClassMethods
    def raw_api_endpoint(hostname, port, path = '')
      URI::HTTPS.build(:host => hostname, :port => port.presence.try(:to_i), :path => path)
    end

    def kubernetes_connect(hostname, port, options)
      require 'kubeclient'

      Kubeclient::Client.new(
        raw_api_endpoint(hostname, port, options[:path]),
        options[:version] || kubernetes_version,
        :ssl_options    => Kubeclient::Client::DEFAULT_SSL_OPTIONS.merge(options[:ssl_options] || {}),
        :auth_options   => kubernetes_auth_options(options),
        :http_proxy_uri => VMDB::Util.http_proxy_uri
      )
    end

    def kubernetes_auth_options(options)
      auth_options = {}
      if options[:username] && options[:password]
        auth_options[:username] = options[:username]
        auth_options[:password] = options[:password]
      end
      auth_options[:bearer_token] = options[:bearer] if options[:bearer]
      auth_options
    end

    def kubernetes_version
      'v1'
    end
  end

  PERF_ROLLUP_CHILDREN = :container_nodes

  def verify_hawkular_credentials
    client = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient.new(self)
    client.hawkular_try_connect
  end

  # UI methods for determining availability of fields
  def supports_port?
    true
  end

  def supports_security_protocol?
    true
  end

  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end

  def verify_ssl_mode(endpoint = default_endpoint)
    return OpenSSL::SSL::VERIFY_PEER if endpoint.nil? # secure by default

    case endpoint.security_protocol
    when nil, ''
      # Previously providers didn't set security_protocol, defaulted to
      # verify_ssl == 1 (VERIFY_PEER) which wasn't enforced but now is.
      # However, if they explicitly set verify_ssl == 0, we'll respect that.
      endpoint.verify_ssl? ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
    when 'ssl-without-validation'
      OpenSSL::SSL::VERIFY_NONE
    else # 'ssl-with-validation', 'ssl-with-validation-custom-ca', secure by default with unexpected values.
      OpenSSL::SSL::VERIFY_PEER
    end
  end

  def ssl_cert_store(endpoint = default_endpoint)
    # Given missing (nil) endpoint, return nil meaning use system CA bundle
    endpoint.try(:ssl_cert_store)
  end

  def connect(options = {})
    effective_options = options.merge(
      :hostname => options[:hostname] || address,
      :port     => options[:port] || port,
      :user     => options[:user] || authentication_userid(options[:auth_type]),
      :pass     => options[:pass] || authentication_password(options[:auth_type]),
      :bearer   => options[:bearer] || authentication_token(options[:auth_type] || 'bearer'),
      :ssl_options => options[:ssl_options] || {
        :verify_ssl => verify_ssl_mode,
        :cert_store => ssl_cert_store
      }
    )
    self.class.raw_connect(effective_options[:hostname], effective_options[:port], effective_options)
  end

  def authentications_to_validate
    at = [:bearer]
    at << :hawkular if has_authentication_type?(:hawkular)
    at
  end

  def required_credential_fields(_type)
    [:auth_key]
  end

  def supported_auth_attributes
    %w(userid password auth_key)
  end

  def verify_credentials(auth_type = nil, options = {})
    options = options.merge(:auth_type => auth_type)
    if options[:auth_type].to_s == "hawkular"
      verify_hawkular_credentials
    else
      with_provider_connection(options, &:api_valid?)
    end
  rescue SocketError,
         Errno::ECONNREFUSED,
         RestClient::ResourceNotFound,
         RestClient::InternalServerError => err
    raise MiqException::MiqUnreachableError, err.message, err.backtrace
  rescue RestClient::Unauthorized   => err
    raise MiqException::MiqInvalidCredentialsError, err.message, err.backtrace
  end

  def ensure_authentications_record
    return if authentications.present?
    update_authentication(:default => {:userid => "_", :save => false})
  end

  def supported_auth_types
    %w(default password bearer)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def default_authentication_type
    :bearer
  end

  def scan_job_create(entity)
    check_policy_prevent(:request_containerimage_scan, entity, :raw_scan_job_create)
  end

  def raw_scan_job_create(target_class, target_id = nil)
    target_class, target_id = target_class.class.name, target_class.id if target_class.kind_of?(ContainerImage)
    Job.create_job(
      "ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job",
      :name            => "Container image analysis",
      :target_class    => target_class,
      :target_id       => target_id,
      :zone            => my_zone,
      :miq_server_host => MiqServer.my_server.hostname,
      :miq_server_guid => MiqServer.my_server.guid,
      :ems_id          => id,
    )
  end

  # policy_event: the event sent to automate for policy resolution
  # cb_method:    the MiqQueue callback method along with the parameters that is called
  #               when automate process is done and the event is not prevented to proceed by policy
  def check_policy_prevent(policy_event, event_target, cb_method)
    cb = {
      :class_name  => self.class.to_s,
      :instance_id => id,
      :method_name => :check_policy_prevent_callback,
      :args        => [cb_method, event_target.class.name, event_target.id],
      :server_guid => MiqServer.my_guid
    }
    enforce_policy(event_target, policy_event, {}, { :miq_callback => cb }) unless policy_event.nil?
  end

  def check_policy_prevent_callback(*action, _status, _message, result)
    prevented = false
    if result.kind_of?(MiqAeEngine::MiqAeWorkspaceRuntime)

      event = result.get_obj_from_path("/")['event_stream']
      data  = event.attributes["full_data"]
      prevented = data.fetch_path(:policy, :prevented) if data
    end
    prevented ? _log.info(event.attributes["message"].to_s) : send(*action)
  end

  def enforce_policy(event_target, event, inputs = {}, options = {})
    MiqEvent.raise_evm_event(event_target, event, inputs, options)
  end

  SCAN_CONTENT_PATH = '/api/v1/content'

  def scan_entity_create(scan_data)
    client = ext_management_system.connect(:service => 'kubernetes')
    pod_proxy = client.proxy_url(:pod,
                                 scan_data[:pod_name],
                                 scan_data[:pod_port],
                                 scan_data[:pod_namespace])
    nethttp_options = {
      :use_ssl     => true,
      :verify_mode => verify_ssl_mode,
      :cert_store  => ssl_cert_store,
    }
    MiqContainerGroup.new(pod_proxy + SCAN_CONTENT_PATH,
                          nethttp_options,
                          client.headers.stringify_keys,
                          scan_data[:guest_os])
  end

  def annotate(provider_entity_name, ems_indentifier, annotations, container_project_name = nil)
    with_provider_connection do |conn|
      conn.send(
        "patch_#{provider_entity_name}".to_sym,
        ems_indentifier,
        {"metadata" => {"annotations" => annotations}},
        container_project_name # nil is ok for non namespaced entities (e.g images)
      )
    end
  end
end
