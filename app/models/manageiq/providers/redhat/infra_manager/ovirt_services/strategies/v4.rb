module ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies
  class V4
    attr_reader :ext_management_system

    def initialize(args)
      @ext_management_system = args[:ems]
    end

    def username_by_href(href)
      ext_management_system.with_provider_connection(:version => 4) do |connection|
        user = connection.system_service.users_service.user_service(get_uuid_from_href(href)).get
        "#{user.name}@#{user.domain.name}"
      end
    end

    def cluster_name_href(href)
      ext_management_system.with_provider_connection(:version => 4) do |connection|
        cluster_proxy_from_href(href, connection).name
      end
    end

    private

    def cluster_proxy_from_href(href, con)
      con.system_service.clusters_service.cluster_service(get_uuid_from_href(href)).get
    end

    def get_uuid_from_href(ems_ref)
      URI(ems_ref).path.split('/').last
    end
  end
end
