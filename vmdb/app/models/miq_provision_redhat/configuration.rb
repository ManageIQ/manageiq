module MiqProvisionRedhat::Configuration
  extend ActiveSupport::Concern

  include_concern 'Container'
  include_concern 'Network'

  def attach_floppy_payload
    payload = floppy_payload
    get_provider_destination.attach_floppy(payload) if payload
  end

  def configure_memory(rhevm_vm)
    vm_memory = get_option(:vm_memory).to_i * 1.megabyte
    set_container_memory(vm_memory, rhevm_vm) unless vm_memory.zero?
  end

  def configure_memory_reserve(rhevm_vm)
    memory_reserve = get_option(:memory_reserve).to_i.megabyte
    set_container_memory_reserve(memory_reserve, rhevm_vm) unless memory_reserve.zero?
  end

  def configure_cpu(rhevm_vm)
    sockets = get_option(:number_of_sockets).to_i
    sockets = 1 if sockets.zero?
    cores = get_option(:cores_per_socket).to_i
    cores = 1 if cores.zero?
    set_container_cpu({:cores => cores, :sockets => sockets}, rhevm_vm)
  end

  def configure_host_affinity(rhevm_vm)
    return if dest_host.nil?
    $log.info("MIQ(#{self.class.name}#configure_host_affinity) Setting Host Affinity to: #{dest_host.name} with ID=#{dest_host.id}")
    rhevm_vm.host_affinity = dest_host.ems_ref
  end

  def configure_container
    rhevm_vm = get_provider_destination

    set_container_description(get_option(:vm_description), rhevm_vm)

    configure_memory(rhevm_vm)
    configure_memory_reserve(rhevm_vm)
    configure_cpu(rhevm_vm)
    configure_host_affinity(rhevm_vm)
    configure_network_adapters
  end

  private

  def floppy_payload
    return nil unless customization_template
    options  = prepare_customization_template_substitution_options
    filename = customization_template.default_filename
    content  = customization_template.script_with_substitution(options)
    {filename => content}
  end
end
