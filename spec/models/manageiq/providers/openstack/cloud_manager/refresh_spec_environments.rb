module Openstack
  module RefreshSpecEnvironments
    def allowed_enviroments
      [:grizzly, :havana]
    end

    def networking_service
      case @environment
      when :grizzly
        :nova
      when :havana
        :neutron
      end
    end

    def neutron_networking?
      networking_service == :neutron
    end
  end
end
