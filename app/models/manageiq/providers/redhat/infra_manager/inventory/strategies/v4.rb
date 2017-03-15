module ManageIQ::Providers::Redhat::InfraManager::Inventory::Strategies
  class V4
    attr_accessor :connection
    attr_reader :ems

    def initialize(args)
      @ems = args[:ems]
    end

    def host_targeted_refresh(target)
      @ems.with_provider_connection(:version => 4) do |connection|
        @connection = connection
        res = {}
        res[:host] = collect_host(get_uuid_from_target(target))
        res
      end
    end

    def vm_targeted_refresh(target)
      @ems.with_provider_connection(:version => 4) do |connection|
        @connection = connection
        vm_id = get_uuid_from_target(target)
        res = {}
        res[:cluster] = collect_clusters
        res[:datacenter] = collect_datacenters
        res[:vm] = collect_vm_by_uuid(vm_id)
        res[:storage] = target.storages.empty? ? collect_storages : collect_storage(target.storages.map { |s| get_uuid_from_target(s) })
        res[:template] = search_templates("vm.id=#{vm_id}")
        res
      end
    end

    def get_uuid_from_target(object)
      get_uuid_from_href(object.ems_ref)
    end

    def get_uuid_from_href(ems_ref)
      URI(ems_ref).path.split('/').last
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

    def collect_cluster_from_href(href, con = nil)
      con ||= connection
      con.system_service.clusters_service.cluster_service(get_uuid_from_href(href)).get
    end

    def get_cluster_name_href(href)
      ems.with_provider_connection do |connection|
        collect_cluster_from_href(href, connection).name
      end
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

    def get_vm_proxy(vm, con = nil)
      con ||= connection
      VmProxyDecorator.new(con.system_service.vms_service.vm_service(vm.uid_ems))
    end

    def get_host_proxy(host, con = nil)
      con ||= connection
      con.system_service.hosts_service.host_service(host.uid_ems)
    end

    def get_template_proxy(template, con = nil)
      con ||= connection
      TemplateProxyDecorator.new(
        con.system_service.templates_service.template_service(template.uid_ems),
        con,
        self
      )
    end

    def collect_vm_by_uuid(uuid)
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

    def collect_username_by_href(href)
      username = nil
      @ems.with_provider_connection(:version => 4) do |connection|
        user = connection.system_service.users_service.user_service(get_uuid_from_href(href)).get
        username = "#{user.name}@#{user.domain.name}"
      end
      username
    end

    def collect_disks_by_hrefs(disks)
      vm_disks = []
      @ems.with_provider_connection(:version => 4) do |connection|
        disks.each do |disk|
          parts = URI(disk).path.split('/')
          begin
            vm_disks << connection.system_service.storage_domains_service.storage_domain_service(parts[2]).disks_service.disk_service(parts[4]).get
          rescue OvirtSDK4::Error
            nil
          end
        end
      end
      vm_disks
    end

    def vm_start(operation, cloud_init)
      opts = {}
      operation.with_provider_object do |rhevm_vm|
        opts = {:use_cloud_init => cloud_init} if start_with_cloud_init
        rhevm_vm.start(opts)
      end
      rescue OvirtSDK4::Error
    end

    def vm_stop(operation)
      operation.with_provider_object(&:stop)
      rescue OvirtSDK4::Error
    end

    def shutdown_guest(operation)
      operation.with_provider_object(&:shutdown)
      rescue OvirtSDK4::Error
    end

    def vm_boot_from_network(operation)
      begin
        operation.get_provider_destination.start(vm: {
            os: {
                boot: {
                    devices: [
                        OvirtSDK4::BootDevice::NETWORK
                    ]
                }
            }
        })
      rescue OvirtSDK4::Error
        raise Inventory::VmNotReadyToBoot
      end
    end

    def vm_boot_from_cdrom(operation, name)
      begin
        operation.get_provider_destination.vm_service.start(
            vm: {
                os: {
                    boot: {
                        devices: [
                            OvirtSDK4::BootDevice::CDROM
                        ]
                    }
                },
                cdroms: [
                    {
                        id: name
                    }
                ]
            }
        )
      rescue OvirtSDK4::Error
        raise Inventory::VmNotReadyToBoot
      end
    end

    def cluster_find_network_by_name(href, network_name)
      @ems.with_provider_connection(:version => 4) do |connection|
        cluster_service = connection.system_service.clusters_service.cluster_service(get_uuid_from_href(href))
        networks = cluster_service.networks_service.list
        networks.detect { |n| n.name == network_name }
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

    def destination_image_locked?(vm)
      vm.with_provider_object do |vm_proxy|
        vm_proxy.get.status == OvirtSDK4::VmStatus::IMAGE_LOCKED
      end
    end

    def get_nics(vm)
      vm.with_provider_connection do |connection|
        vm_proxy = connection.system_service.vms_service.vm_service(vm.uid_ems).get
        connection.follow_link(vm_proxy.nics)
      end
    end

    def get_network_profile_id(connection, network_id)
      profiles_service = connection.system_service.vnic_profiles_service
      profile = profiles_service.list.detect{ |profile| profile.network.id == network_id }
      profile && profile.id
    end

    def configure_vnic(args)
      vm = args[:vm]
      mac_addr = args[:mac_addr]
      network = args[:network]
      nic_name = args[:nic_name]
      interface = args[:interface]
      vnic = args[:vnic]
      logger = args[:logger]

      vm.with_provider_connection do |connection|
        uuid = get_uuid_from_href vm.ems_ref
        profile_id = get_network_profile_id(connection, network.id)
        nics_service = connection.system_service.vms_service.vm_service(uuid).nics_service
        options = {
                    :name         => nic_name || vnic.name,
                    :interface    => interface || vnic.interface,
                    :mac          => mac_addr ? OvirtSDK4::Mac.new({:address => mac_addr}) : vnic.mac,
                    :vnic_profile => profile_id ? { id: profile_id } : vnic.vnic_profile
                  }
        logger.info("with options: <#{options.inspect}>")
        if vnic
          nics_service.nic_service(vnic.id).update(options)
        else
          nics_service.add(OvirtSDK4::Nic.new(options))
        end
      end
    end

    def clone_completed?(args)
      phase_context = args[:phase_context]
      logger = args[:logger]
      connection = args[:connection]
      vm = get_vm_service_by_href(phase_context[:new_vm_ems_ref], connection).get
      status = vm.status
      logger.info("The Vm being cloned is #{status}")
      status == OvirtSDK4::VmStatus::DOWN
    end

    def get_vm_service_by_href(href, con)
      con ||= connection
      vm_uuid = get_uuid_from_href(href)
      con.system_service.vms_service.vm_service(vm_uuid)
    end

    def populate_phase_context(phase_context, vm)
      phase_context[:new_vm_ems_ref] = ManageIQ::Providers::Redhat::InfraManager.make_ems_ref(vm.href)
    end

    def powered_off_in_provider?(vm)
      vm.with_provider_object { |vm_service| vm_service.get.status } == OvirtSDK4::VmStatus::DOWN
    end

    def powered_on_in_provider?(vm)
      vm.with_provider_object { |vm_service| vm_service.get.status } == OvirtSDK4::VmStatus::UP
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

    class TemplateProxyDecorator < SimpleDelegator
      attr_reader :connection, :inventory
      def initialize(template_service, connection, inventory)
        @obj = template_service
        @connection = connection
        @inventory = inventory
        super(template_service)
      end

      def create_vm(options)
        vms_service = connection.system_service.vms_service
        cluster = inventory.collect_cluster_from_href(options[:cluster], connection)
        template = get
        vm = build_vm_from_hash(:name     => options[:name],
                                :template => template,
                                :cluster  => cluster)
        vms_service.add(vm)
      end

      def build_vm_from_hash(args)
        OvirtSDK4::Vm.new(:name => args[:name],
                          :template => args[:template],
                          :cluster => args[:cluster])
      end
    end

    class VmProxyDecorator < SimpleDelegator
      def update_memory_reserve!(memory_reserve_size)
        vm = get
        vm.memory_policy.guaranteed = memory_reserve_size
        update(vm)
      end

      def update_description!(description)
        vm = get
        vm.description = description
        update(vm)
      end

      def update_memory!(memory)
        vm = get
        vm.memory = memory
        update(vm)
      end

      def update_host_affinity!(dest_host_ems_ref)
        vm = get
        host = collect_host(dest_host_ems_ref)
        vm.placement_policy.hosts = [host]
        update(vm)
      end

      def update_cpu_topology!(cpu_hash)
        vm = get
        vm.cpu.topology = OvirtSDK4::CpuTopology.new(cpu_hash)
        update(vm)
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
end
