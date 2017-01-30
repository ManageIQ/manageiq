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

    def verify_ssl_mode
      # TODO: support real authentication using certificates
      OpenSSL::SSL::VERIFY_NONE
    end

    def kubernetes_connect(hostname, port, options)
      require 'kubeclient'

      Kubeclient::Client.new(
        raw_api_endpoint(hostname, port, options[:path]),
        options[:version] || kubernetes_version,
        :ssl_options    => { :verify_ssl => verify_ssl_mode },
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

  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end

  def verify_ssl_mode
    # TODO: support real authentication using certificates
    self.class.verify_ssl_mode
  end

  def connect(options = {})
    options[:hostname] ||= address
    options[:port] ||= port
    options[:user] ||= authentication_userid(options[:auth_type])
    options[:pass] ||= authentication_password(options[:auth_type])
    options[:bearer] ||= authentication_token(options[:auth_type] || 'bearer')
    self.class.raw_connect(options[:hostname], options[:port], options)
  end

  def authentications_to_validate
    at = [:bearer]
    at << :hawkular if has_authentication_type?(:hawkular)
    at
  end

  def required_credential_fields(_type)
    [:auth_key]
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
    check_policy_prevent(:request_containerimage_scan, entity, :raw_scan_job_create, entity)
  end

  def raw_scan_job_create(entity)
    Job.create_job(
      "ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job",
      :name            => "Container image analysis",
      :target_class    => entity.class.name,
      :target_id       => entity.id,
      :zone            => my_zone,
      :miq_server_host => MiqServer.my_server.hostname,
      :miq_server_guid => MiqServer.my_server.guid,
      :ems_id          => id,
    )
  end

  # policy_event: the event sent to automate for policy resolution
  # cb_method:    the MiqQueue callback method along with the parameters that is called
  #               when automate process is done and the event is not prevented to proceed by policy
  def check_policy_prevent(policy_event, event_target, *cb_method)
    cb = {
      :class_name  => self.class.to_s,
      :instance_id => id,
      :method_name => :check_policy_prevent_callback,
      :args        => [*cb_method],
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
    MiqContainerGroup.new(pod_proxy + SCAN_CONTENT_PATH,
                          verify_ssl_mode,
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
