class ManageIQ::Providers::Vmware::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  def self.ems_inv_to_hashes(ems, options = nil)
    new(ems, options).ems_inv_to_hashes
  end

  def initialize(ems, options = Config::Options.new)
    @ems                 = ems
    @data                = {}
    @data_index          = {}
    @options             = options
  end

  def process_collection(collection, key)
    @data[key] ||= []

    collection.each do |item|
      uid, new_result = yield(item)
      next if uid.nil?

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $log.info("#{log_header}...")

    vcd = @ems.vcd_service

    @ems.api_version = vcd.api_version

    @inv = {
      :orgs  => [],
      :vdcs  => [],
      :vapps => [],
      :vms   => [],
    }

    @inv[:orgs] = vcd.organizations.all.to_a

    @inv[:orgs].each do |org|
      @inv[:vdcs] += org.vdcs.all
    end

    @inv[:vdcs].each do |vdc|
      @inv[:vapps] += vdc.vapps.all
    end

    @inv[:vapps].each do |vapp|
      @inv[:vms] += vapp.vms.all
    end

    get_vms

    $log.info("#{log_header}...Complete")

    @data
  end

  private

  def get_vms
    process_collection(@inv[:vms], :vms) { |vm| parse_vm(vm) }
  end

  def parse_vm(vm)
    status = vm.status

    uid           = vm.id
    name          = vm.name
    guest_os      = vm.operating_system
    bitness       = vm.operating_system =~ /64-bit/ ? 64 : 32
    cpus          = vm.cpu
    memory_mb     = vm.memory
    disk_capacity = vm.hard_disks.inject(0) { |sum, x| sum + x.values[0] } * 1.megabyte

    vm_disks = vm.disks.all

    disks = vm_disks.select { |d| d.description == "Hard disk" }.map do |disk|
      parent = vm_disks.find { |d| d.id == disk.parent }

      {
        :device_name     => disk.name,
        :device_type     => "disk",
        :controller_type => parent.description,
        :size            => disk.capacity * 1.megabyte,
        :location        => "#{vm.id}-#{disk.id}",
        :filename        => "#{vm.id}-#{disk.id}",
      }
    end

    networks = vm.network_adapters.map do |net|
      {
        :description => "private",
        :ipaddress   => net[:ip_address],
      }
    end

    new_result = {
      :type                => ManageIQ::Providers::Vmware::CloudManager::Vm.name,
      :uid_ems             => uid,
      :ems_ref             => uid,
      :name                => name,
      :vendor              => "vmware",
      :raw_power_state     => status,
      :boot_time           => nil,

      :hardware            => {
        :guest_os             => guest_os,
        :guest_os_full_name   => guest_os,
        :bitness              => bitness,
        :virtualization_type  => nil,
        :root_device_type     => nil,
        :cpu_sockets          => cpus,
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => cpus,
        :memory_mb            => memory_mb,
        :disk_capacity        => disk_capacity,
        :disks                => disks,
        :networks             => networks,
      },

      :operating_system    => {
        :product_name => guest_os,
      },

      :cloud_network       => nil,
      :cloud_subnet        => nil,
      :orchestration_stack => nil,
    }

    return uid, new_result
  end
end
