module ManageIQ::Providers
  class Hawkular::MiddlewareManager < ManageIQ::Providers::MiddlewareManager
    require_nested :RefreshParser
    require_nested :Refresher

    include AuthenticationMixin

    has_many :middleware_servers, :foreign_key => :ems_id

    def self.raw_connect(hostname, username, password)
      require 'hawkular_all'
      ::Hawkular::Inventory::InventoryClient.new(hostname, :username => username, :password => password)
    end

    def connect
      @connection ||= self.class.raw_connect(hostname, *auth_user_pwd)
    end

    def connection
      connect
    end

    def feeds
      connection.list_feeds
    end

    def eaps(feed)
      connection.list_resources_for_type(feed, 'WildFly Server')
    end

    def deployments(feed)
      connection.list_resources_for_type(feed, 'Deployment')
    end
  end
end
