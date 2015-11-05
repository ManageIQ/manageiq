module ManageiqForeman
  class Inventory
    attr_accessor :connection

    def initialize(connection)
      @connection = connection
    end

    def refresh_configuration(_target = nil)
      hosts = connection.all(:hosts)
      hostgroups = connection.all(:hostgroups)

      # if locations or organizations are enabled (detected by presence in host records)
      #    but it is not present in hostgroups
      #   fetch details for a hostgroups (to get location and organization information)
      host = hosts.first
      hostgroup = hostgroups.first
      if (host && hostgroup && (
          (host.key?("location_id") && !hostgroup.key?("locations")) ||
          (host.key?("organization_id") && !hostgroup.key?("organizations"))))
        hostgroups = connection.load_details(hostgroups, :hostgroups)
      end
      {
        :hosts      => hosts,
        :hostgroups => hostgroups
      }
    end

    def refresh_provisioning(_target = nil)
      {
        :operating_systems => connection.all_with_details(:operatingsystems),
        :media             => connection.all(:media),
        :ptables           => connection.all(:ptables),
        :locations         => connection.all(:locations),
        :organizations     => connection.all(:organizations),
        :architectures     => connection.all(:architectures),
        :compute_profiles  => connection.all(:compute_profiles),
        :domains           => connection.all(:domains),
        :environments      => connection.all(:environments),
        :realms            => connection.all(:realms),
      }
    end
  end
end
