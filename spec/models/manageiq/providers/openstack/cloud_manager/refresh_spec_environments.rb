module Openstack
  module RefreshSpecEnvironments
    def allowed_enviroments
      [:grizzly, :havana, :icehouse, :juno, :kilo, :kilo_keystone_v3]
    end

    def networking_service
      case @environment
      when :grizzly
        :nova
      else
        :neutron
      end
    end

    def identity_service
      case @environment
      when :kilo_keystone_v3
        :v3
      else
        :v2
      end
    end

    def environment_release_number
      case @environment
      when :kilo, :kilo_keystone_v3
        7
      when :juno
        6
      when :icehouse
        5
      when :havana
        4
      when :grizzly
        3
      end
    end

    def keystone_v3_identity?
      identity_service == :v3
    end

    def neutron_networking?
      networking_service == :neutron
    end

    def storage_supported?
      # We support storage from Havana
      environment_release_number >= 4
    end

    def orchestration_supported?
      # We support orchestration from Havana
      environment_release_number >= 4
    end
  end
end
