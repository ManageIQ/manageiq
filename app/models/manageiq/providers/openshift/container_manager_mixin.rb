module ManageIQ::Providers::Openshift::ContainerManagerMixin
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  DEFAULT_PORT = 8443

  included do
    has_many :container_routes, :foreign_key => :ems_id, :dependent => :destroy
    default_value_for :port, DEFAULT_PORT
  end

  # This is the API version that we use and support throughout the entire code
  # (parsers, events, etc.). It should be explicitly selected here and not
  # decided by the user nor out of control in the defaults of openshift gem
  # because it's not guaranteed that the next default version will work with
  # our specific code in ManageIQ.
  delegate :api_version, :to => :class

  def api_version=(_value)
    raise 'OpenShift api_version cannot be modified'
  end

  class_methods do
    def api_version
      'v1'
    end

    def raw_connect(hostname, port, options)
      options[:service] ||= "openshift"
      send("#{options[:service]}_connect", hostname, port, options)
    end

    def openshift_connect(hostname, port, options)
      require 'openshift_client'

      OpenshiftClient::Client.new(
        raw_api_endpoint(hostname, port),
        api_version,
        :ssl_options  => {:verify_ssl => verify_ssl_mode},
        :auth_options => kubernetes_auth_options(options),
      )
    end
  end
end
