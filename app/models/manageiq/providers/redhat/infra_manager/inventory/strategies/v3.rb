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

    def get_vm_proxy(vm, connection)
      connection ||= ext_management_system.connect
      connection.get_resource_by_ems_ref(vm.ems_ref)
    end

    def collect_disks_by_hrefs(disks)
      vm_disks = []

      ext_management_system.with_provider_connection do |rhevm|
        disks.each do |disk|
          begin
            vm_disks << Ovirt::Disk.find_by_href(rhevm, disk)
          rescue Ovirt::MissingResourceError
            nil
          end
        end
      end
      vm_disks
    end

    def vm_start(operation, cloud_init)
      operation.with_provider_object do |rhevm_vm|
        rhevm_vm.start { |action| action.use_cloud_init(true) if cloud_init }
      end
      rescue Ovirt::VmAlreadyRunning
    end

    def vm_stop(operation)
      operation.with_provider_object(&:stop)
      rescue Ovirt::VmIsNotRunning
    end

    def shutdown_guest(operation)
      operation.with_provider_object(&:shutdown)
      rescue Ovirt::VmIsNotRunning
    end

    def vm_boot_from_network(operation)
      begin
        operation.get_provider_destination.boot_from_network
      rescue Ovirt::VmNotReadyToBoot
        raise Inventory::VmNotReadyToBoot
      end
    end

    def vm_boot_from_cdrom(operation, name)
      begin
        operation.get_provider_destination.boot_from_cdrom(name)
      rescue Ovirt::VmNotReadyToBoot
        raise Inventory::VmNotReadyToBoot
      end
    end

    def cluster_find_network_by_name(href, network_name)
      ext_management_system.with_provider_connection do |rhevm|
        Ovirt::Cluster.find_by_href(rhevm, href).try(:find_network_by_name, network_name)
      end
    end
  end
end
