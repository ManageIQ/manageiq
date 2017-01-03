module ManageIQ::Providers::Redhat::InfraManager::Refresh::Strategies
  class Api4 < ManageIQ::Providers::Redhat::InfraManager::Refresh::Refresher
    attr_reader :ems

    def inventory_from_ovirt(ems)
      @ems = ems
      InventoryWrapper.new(old_inventory: super, ems: ems)
    end

    class InventoryWrapper
      attr_reader :old_inventory
      attr_reader :ems

      def initialize(args)
        @ems = args[:ems]
        @old_inventory = args[:old_inventory]
      end

      def refresh
        res = {}# old_inventory.refresh
        res[:cluster] = collect_clusters
        res[:storage] = collect_storages
        res[:host] = collect_hosts
        res[:vm] = collect_vms
        res[:template] = collect_templates
        res[:network] = collect_networks
        res
      end

      def collect_clusters
        clusters = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.clusters_service.list
        end
        clusters.collect {|c| BracketNotationDecorator.new(c) }
      end

      def collect_storages
        storagess = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.storage_domains_service.list
        end
        storagess.collect {|s| BracketNotationDecorator.new(s) }
      end

      def collect_hosts
        hosts = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.hosts_service.list.collect do |h|
            HostPreloadedAttributesDecorator.new(h, connection)
          end
        end
        hosts.collect { |h| BracketNotationDecorator.new(h) }
      end

      def collect_vms
        vms = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.vms_service.list.collect do |vm|
            VmPreloadedAttributesDecorator.new(vm, connection)
          end
        end
        vms.collect { |vm| BracketNotationDecorator.new(vm) }
      end

      def collect_templates
        templates = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.templates_service.list.collect do |template|
            TemplatePreloadedAttributesDecorator.new(template, connection)
          end
        end
        templates.collect { |template| BracketNotationDecorator.new(template) }
      end

      def collect_networks
        networks = @ems.with_provider_connection(:version => 4) do |connection|
          connection.system_service.networks_service.list
        end
        networks.collect { |template| BracketNotationDecorator.new(template) }
      end

      def api
        old_inventory.api
      end

      def service
        old_inventory.service
      end
    end
  end

  class BracketNotationDecorator < SimpleDelegator
    ALLOWED_METHODS = ["id", "name", "href"]

    def initialize(obj)
      @obj = obj
      super
    end

    def [](key)
      return super unless ALLOWED_METHODS.include?(key.to_s)
      @obj.send(key)
    end

    def attributes
      instance_values
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
