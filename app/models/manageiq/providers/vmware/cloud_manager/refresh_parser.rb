class ManageIQ::Providers::Vmware::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  include ManageIQ::Providers::Vmware::RefreshHelperMethods

  def initialize(ems, options = nil)
    @ems        = ems
    @connection = ems.connect
    @options    = options || {}
    @data       = {}
    @data_index = {}
    @inv        = Hash.new { |h, k| h[k] = [] }
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $log.info("#{log_header}...")

    get_ems
    get_orgs
    get_vdcs
    get_vapps
    get_vms

    $log.info("#{log_header}...Complete")

    @data
  end

  private

  def get_ems
    @ems.api_version = @connection.api_version
  end

  def get_orgs
    @inv[:orgs] = @connection.organizations.all.to_a
  end

  def get_vdcs
    @inv[:orgs].each do |org|
      @inv[:vdcs] += org.vdcs.all
    end
  end

  def get_vapps
    @inv[:vdcs].each do |vdc|
      @inv[:vapps] += vdc.vapps.all
    end
  end

  def get_vms
    @inv[:vapps].each do |vapp|
      @inv[:vms] += vapp.vms.all
    end

    process_collection(@inv[:vms], :vms) { |vm| parse_vm(vm) }
  end

  def parse_vm(vm)
    status        = vm.status
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

    new_result = {
      :type             => ManageIQ::Providers::Vmware::CloudManager::Vm.name,
      :uid_ems          => uid,
      :ems_ref          => uid,
      :name             => name,
      :vendor           => "vmware",
      :raw_power_state  => status,

      :hardware         => {
        :guest_os             => guest_os,
        :guest_os_full_name   => guest_os,
        :bitness              => bitness,
        :cpu_sockets          => cpus,
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => cpus,
        :memory_mb            => memory_mb,
        :disk_capacity        => disk_capacity,
        :disks                => disks,
      },

      :operating_system => {
        :product_name => guest_os,
      },
    }

    return uid, new_result
  end
end
