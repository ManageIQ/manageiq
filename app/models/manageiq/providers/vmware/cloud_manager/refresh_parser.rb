class ManageIQ::Providers::Vmware::CloudManager::RefreshParser < ManageIQ::Providers::CloudManager::RefreshParser
  include ManageIQ::Providers::Vmware::RefreshHelperMethods

  # While parsing the VMWare catalog only those vapp templates whose status
  # is reported to be "8" are ready to be used. The documentation says this
  # status is POWERED_OFF, however the cloud director shows it as "Ready"
  VAPP_TEMPLATE_STATUS_READY = "8".freeze

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
    get_vapp_templates
    get_images

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

    process_collection(@inv[:vapps], :orchestration_stacks) { |vapp| parse_stack(vapp) }
  end

  def get_vms
    @inv[:vapps].each do |vapp|
      @inv[:vms] += vapp.vms.all
    end

    process_collection(@inv[:vms], :vms) { |vm| parse_vm(vm) }
  end

  def get_vapp_templates
    @inv[:orgs].each do |org|
      org.catalogs.each do |catalog|
        next if catalog.is_published && !@options.get_public_images

        catalog.catalog_items.each do |item|
          @inv[:vapp_templates] << {
            :vapp_template => item.vapp_template,
            :is_published  => catalog.is_published
          } if item.vapp_template.status == VAPP_TEMPLATE_STATUS_READY
        end
      end
    end
  end

  def get_images
    @inv[:vapp_templates].each do |template_obj|
      @inv[:images] += template_obj[:vapp_template].vms.map { |image| { :image => image, :is_published => template_obj[:is_published] } }
    end

    process_collection(@inv[:images], :vms) { |image_obj| parse_image(image_obj[:image], image_obj[:is_published]) }
  end

  def parse_vm(vm)
    status        = vm.status
    uid           = vm.id
    name          = vm.name
    guest_os      = vm.operating_system
    bitness       = vm.operating_system =~ /64-bit/ ? 64 : 32
    cpus          = vm.cpu
    memory_mb     = vm.memory
    vapp_uid      = vm.vapp_id
    stack         = @data_index.fetch_path(:orchestration_stacks, vapp_uid)
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
      :type                => ManageIQ::Providers::Vmware::CloudManager::Vm.name,
      :uid_ems             => uid,
      :ems_ref             => uid,
      :name                => name,
      :vendor              => "vmware",
      :raw_power_state     => status,

      :hardware            => {
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

      :operating_system    => {
        :product_name => guest_os,
      },

      :orchestration_stack => stack,
    }

    return uid, new_result
  end

  def parse_stack(vapp)
    status   = vapp.human_status
    uid      = vapp.id
    name     = vapp.name

    new_result = {
      :type        => ManageIQ::Providers::Vmware::CloudManager::OrchestrationStack.name,
      :ems_ref     => uid,
      :name        => name,
      :description => name,
      :status      => status,
    }
    return uid, new_result
  end

  def parse_image(image, is_public)
    uid  = image.id
    name = image.name

    new_result = {
      :type               => ManageIQ::Providers::Vmware::CloudManager::Template.name,
      :uid_ems            => uid,
      :ems_ref            => uid,
      :name               => name,
      :vendor             => "vmware",
      :raw_power_state    => "never",
      :publicly_available => is_public
    }

    return uid, new_result
  end
end
