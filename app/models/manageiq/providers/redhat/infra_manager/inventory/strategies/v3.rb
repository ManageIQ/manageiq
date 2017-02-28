module ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies
  class V3
    attr_reader :ext_management_system

    def initialize(args)
      @ext_management_system = args[:ems]
    end

    def collect_username_by_href(href)
      username = nil
      ext_management_system.with_provider_connection do |rhevm|
        username = Ovirt::User.find_by_href(rhevm, href).try(:[], :user_name)
      end
      username
    end

    def collect_cluster_name_href(href)
      ext_management_system.with_provider_connection do |rhevm|
        Ovirt::Cluster.find_by_href(rhevm, href).try(:[], :name)
      end
    end
  end
end
