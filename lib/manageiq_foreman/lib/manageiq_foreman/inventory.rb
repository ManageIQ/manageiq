module ManageiqForeman
  class Inventory
    attr_accessor :connection

    def initialize(connection)
      @connection = connection
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
  end
end
