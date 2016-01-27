module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require_nested :RefreshParser
    require_nested :RefreshWorker
    require_nested :Refresher

    include AuthenticationMixin

    DEFAULT_PORT = 80
    default_value_for :port, DEFAULT_PORT
    has_many :middleware_servers, :foreign_key => :ems_id, :dependent => :destroy
    has_many :middleware_deployments, :foreign_key => :ems_id, :dependent => :destroy

    def verify_credentials(auth_type = nil, options = {})
      auth_type ||= 'default'
    end

    def self.raw_connect(hostname, port, username, password)
      require 'hawkular_all'
      url = URI::HTTP.build(:host => hostname, :port => port.to_i, :path => "/hawkular/inventory").to_s
      ::Hawkular::Inventory::InventoryClient.new(url, :username => username, :password => password)
    end

    def connect
      $hawk_log.info("Connecting to Hawkular on #{hostname}:#{port}")
      @connection ||= self.class.raw_connect(hostname, port, authentication_userid('default'), authentication_password('default'))
    end

    def connection
      connect
    end

    def browser_url
      "http://#{hostname}:#{port}"
    end

    def feeds
      $hawk_log.info('connection class ' + connection.class.to_s)
      if connection.respond_to? :to_s
        $hawk_log.info(connection.to_s)
      end
      connection.list_feeds
    end

    def eaps(feed)
      connection.list_resources_for_type(feed, 'WildFly Server', true)
    end

    def children(eap_parent)
      connection.list_child_resources(eap_parent)
    end

    # UI methods for determining availability of fields
    def supports_port?
      true
    end

    def self.ems_type
      @ems_type ||= "hawkular".freeze
    end

    def self.description
      @description ||= "Hawkular".freeze
    end


  end
end
