module ManageiqForeman
  class Inventory
    attr_accessor :connection
    def initialize(connection)
      @connection = connection
    end

    def connect
      # NOP
    end

    def disconnect
      # NOP
    end

    def refresh_configuration(_target = nil)
      {
        :hosts      => connection.all(:hosts),
        :hostgroups => connection.all(:hostgroups).denormalize,
      }
    end

    def refresh_provisioning(_target = nil)
      {
        :operating_systems => connection.all_with_details(:operating_systems),
        :media             => connection.all(:media),
        :ptables           => connection.all(:ptables),
      }
    end

    # expecting: base_url, username, password, :verify_ssl
    def self.from_attributes(connection_attrs)
      new(Connection.new(connection_attrs))
    end
  end
end
