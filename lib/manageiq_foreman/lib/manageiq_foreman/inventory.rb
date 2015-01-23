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

    def refresh(target = nil)
      refresh_all(target)
    end

    # generate inventory for the foreman provider
    def refresh_all(target = nil)
      refresh_configuration(target).merge(refresh_provisioning)
    end

    def refresh_configuration(_target = nil)
      {
        :hosts      => connection.all(:hosts),
        :hostgroups => connection.denormalized_hostgroups,
      }
    end

    def refresh_provisioning(_target = nil)
      {
        :operating_systems => connection.all(:operating_system_details),
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
