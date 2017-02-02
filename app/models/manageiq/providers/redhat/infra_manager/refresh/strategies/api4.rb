module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    attr_reader :ems

    def inventory_from_ovirt(ems)
      @ems = ems
      InventoryWrapper.new(old_inventory: super, ems: ems)
    end

    class InventoryWrapper
      attr_reader :old_inventory
      attr_accessor :connection
      attr_reader :ems

      def initialize(args)
        @ems = args[:ems]
        @old_inventory = args[:old_inventory]
      end

      def targeted_refresh(methods)
        old_inventory.targeted_refresh(methods)
      end

      def refresh
        @ems.with_provider_connection(:version => 4) do |connection|
          @connection = connection
          res = {}
          res[:cluster] = collect_clusters
          res[:storage] = collect_storages
          res[:host] = collect_hosts
          res[:vm] = collect_vms
          res[:template] = collect_templates
          res[:network] = collect_networks
          res[:datacenter] = collect_datacenters
          res
        end
      end

      def collect_clusters
        connection.system_service.clusters_service.list
      end

      def collect_storages
        connection.system_service.storage_domains_service.list
      end

      def collect_hosts
        connection.system_service.hosts_service.list.collect do |h|
          HostPreloadedAttributesDecorator.new(h, connection)
        end
      end

      def collect_vms
        connection.system_service.vms_service.list.collect do |vm|
          VmPreloadedAttributesDecorator.new(vm, connection)
        end
      end

      def collect_templates
        connection.system_service.templates_service.list.collect do |template|
          TemplatePreloadedAttributesDecorator.new(template, connection)
        end
      end

      def collect_networks
        connection.system_service.networks_service.list
      end

      def collect_datacenters
        connection.system_service.data_centers_service.list.collect do |datacenter|
          DatacenterPreloadedAttributesDecorator.new(datacenter, connection)
        end
      end

      def api
        @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.get.product_info.version.full_version
        end
      end

      def service
        @ems.with_provider_connection(:version => 4) do |connection|
         OpenStruct.new(version_string: connection.system_service.get.product_info.version.full_version)
        end
      end
    end
  end

  class HostPreloadedAttributesDecorator < SimpleDelegator
    attr_reader :nics, :statistics
    def initialize(host, connection)
      @obj = host
      @nics = connection.follow_link(host.nics)
      @statistics = connection.follow_link(host.statistics)
      super(host)
    end
  end

  class DatacenterPreloadedAttributesDecorator < SimpleDelegator
    attr_reader :storage_domains
    def initialize(datacenter, connection)
      @obj = datacenter
      @storage_domains = connection.follow_link(datacenter.storage_domains)
      super(datacenter)
    end
  end

  class VmPreloadedAttributesDecorator < SimpleDelegator
    attr_reader :disks, :nics, :reported_devices, :snapshots
    def initialize(vm, connection)
      @obj = vm
      @disks = self.class.get_attached_disks(vm, connection)
      @nics = connection.follow_link(vm.nics)
      @reported_devices = connection.follow_link(vm.reported_devices)
      @snapshots = connection.follow_link(vm.snapshots)
      super(vm)
    end

    def self.get_attached_disks(vm, connection)
      AttachedDisksFetcher.get_attached_disks(vm, connection)
    end
  end

  class AttachedDisksFetcher
    def self.get_attached_disks(disks_owner, connection)
      attachments = connection.follow_link(disks_owner.disk_attachments)
      attachments.map do |attachment|
        res = connection.follow_link(attachment.disk)
        res.interface = attachment.interface
        res.bootable = attachment.bootable
        res.active = attachment.active
        res
      end
    end
  end

  class TemplatePreloadedAttributesDecorator < SimpleDelegator
    attr_reader :disks, :nics
    def initialize(template, connection)
      @obj = template
      @disks = AttachedDisksFetcher.get_attached_disks(template, connection)
      @nics = connection.follow_link(template.nics)
      super(template)
    end
  end
end
