module Openstack
  module RefreshSpecEnvironments
    def allowed_enviroments
      [:grizzly, :havana, :kilo_keystone_v3]
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

    def keystone_v3_identity?
      identity_service == :v3
    end

    def neutron_networking?
      networking_service == :neutron
    end
  end
end
