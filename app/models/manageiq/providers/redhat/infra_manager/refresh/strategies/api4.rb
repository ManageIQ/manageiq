module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    attr_reader :ems

    def host_targeted_refresh(inventory, target)
      inventory.host_targeted_refresh(target)
    end

    def vm_targeted_refresh(inventory, target)
      inventory.vm_targeted_refresh(target)
    end

    require 'uri'

    def inventory_from_ovirt(ems)
      @ems = ems
      InventoryWrapper.new(:ems => ems)
    end

    class InventoryWrapper
      attr_accessor :connection
      attr_reader :ems

      def initialize(args)
        @ems = args[:ems]
      end

      def host_targeted_refresh(target)
        @ems.with_provider_connection(:version => 4) do |connection|
          @connection = connection
          res = {}
          res[:host] = collect_host(get_uuid(target))
          res
        end
      end

      def vm_targeted_refresh(target)
        @ems.with_provider_connection(:version => 4) do |connection|
          @connection = connection
          vm_id = get_uuid(target)
          res = {}
          res[:cluster] = collect_clusters
          res[:datacenter] = collect_datacenters
          res[:vm] = collect_vm(vm_id)
          res[:storage] = target.storages.empty? ? collect_storages : collect_storage(target.storages.map { |s| get_uuid(s) })
          res[:template] = search_templates("vm.id=#{vm_id}")
          res
        end
      end

      def get_uuid(object)
        URI(object.ems_ref).path.split('/').last
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

      def collect_storage(uuids)
        uuids.collect do |uuid|
          connection.system_service.storage_domains_service.storage_domain_service(uuid).get
        end
      end

      def collect_hosts
        connection.system_service.hosts_service.list.collect do |h|
          HostPreloadedAttributesDecorator.new(h, connection)
        end
      end

      def collect_host(uuid)
        host = connection.system_service.hosts_service.host_service(uuid).get
        [HostPreloadedAttributesDecorator.new(host, connection)]
      end

      def collect_vms
        connection.system_service.vms_service.list.collect do |vm|
          VmPreloadedAttributesDecorator.new(vm, connection)
        end
      end

      def collect_vm(uuid)
        vm = connection.system_service.vms_service.vm_service(uuid).get
        [VmPreloadedAttributesDecorator.new(vm, connection)]
      end

      def collect_templates
        connection.system_service.templates_service.list.collect do |template|
          TemplatePreloadedAttributesDecorator.new(template, connection)
        end
      end

      def search_templates(search)
        connection.system_service.templates_service.list(:search => search).collect do |template|
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
          OpenStruct.new(:version_string => connection.system_service.get.product_info.version.full_version)
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
