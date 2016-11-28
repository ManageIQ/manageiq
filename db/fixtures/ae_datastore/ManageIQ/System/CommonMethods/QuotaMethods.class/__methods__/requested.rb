#
# Description: Calculate requested quota items.
#

def request_info
  @service = ($evm.root['vmdb_object_type'] == 'service_template_provision_request') ? true : false
  @miq_request = $evm.root['miq_request']
  $evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")
end

def cloud?(prov_type)
  %w(amazon openstack google).include?(prov_type)
end

def calculate_requested(options_hash = {})
  {:storage => get_total_requested(options_hash, :storage),
   :memory  => get_total_requested(options_hash, :vm_memory),
   :cpu     => get_total_requested(options_hash, :number_of_cpus),
   :vms     => get_total_requested(options_hash, :number_of_vms)}
end

def get_total_requested(options_hash, prov_option)
  total_requested = collect_template_totals(prov_option)
  total_requested = request_totals(total_requested.to_i,
                                   collect_dialog_totals(prov_option, options_hash).to_i) if options_hash
  total_requested
end

def request_totals(template_totals, dialog_totals)
  [template_totals, dialog_totals].max
end

def collect_template_totals(prov_option)
  @service ? collect_totals(service_prov_option(prov_option)) : collect_totals(vm_prov_option_value(prov_option))
end

def get_option_value(request, option)
  request.get_option(option).to_i
end

def service_prov_option(prov_option, options_array = [])
  @service_template.service_resources.each do |child_service_resource|
    if @service_template.service_type == 'composite'
      composite_service_options_value(child_service_resource, prov_option, options_array)
    else
      next if @service_template.prov_type.starts_with?("generic")
      service_prov_option_value(prov_option, child_service_resource.resource, options_array)
    end
  end
  options_array
end

def service_prov_option_value(prov_option, resource, options_array = [])
  args_hash = {:prov_option   => prov_option,
               :options_array => options_array,
               :resource      => resource,
               :flavor        => flavor_obj(resource.get_option(:instance_type)),
               :number_of_vms => get_option_value(resource, :number_of_vms),
               :cloud         => cloud?(resource.get_option(:st_prov_type))}

  case prov_option
  when :vm_memory
    requested_memory(args_hash, get_option_value(resource, :prov_type))
  when :number_of_cpus
    requested_number_of_cpus(args_hash)
  when :storage
    requested_storage(args_hash)
  else
    options_value(args_hash)
  end
  options_array
end

def vm_provision_cloud?
  @miq_request.source.try(:cloud) || false
end

def flavor_obj(id)
  vmdb_object('flavor', id)
end

def vm_prov_option_value(prov_option, options_array = [])
  args_hash = {:prov_option   => prov_option,
               :options_array => options_array,
               :resource      => @miq_request,
               :flavor        => flavor_obj(@miq_request.get_option(:instance_type)),
               :number_of_vms => get_option_value(@miq_request, :number_of_vms),
               :cloud         => vm_provision_cloud?}

  case prov_option
  when :vm_memory
    requested_memory(args_hash, @miq_request.source.vendor)
  when :number_of_cpus
    requested_number_of_cpus(args_hash)
  when :storage
    requested_storage(args_hash)
  else
    options_value(args_hash)
  end
  options_array
end

def requested_memory(args_hash, vendor)
  memory = get_option_value(args_hash[:resource], :vm_memory)
  memory = memory.megabytes if %w(amazon openstack google).exclude?(vendor)
  args_hash[:prov_value] = args_hash[:number_of_vms] * memory
  request_hash_value(args_hash)
end

def requested_number_of_cpus(args_hash)
  cpu_in_request = get_option_value(args_hash[:resource], :number_of_sockets) *
                   get_option_value(args_hash[:resource], :cores_per_socket)
  cpu_in_request = get_option_value(args_hash[:resource], args_hash[:number_of_cpus]) if cpu_in_request.zero?
  args_hash[:prov_value] = args_hash[:number_of_vms] * cpu_in_request
  request_hash_value(args_hash)
end

def vmdb_object(model, id)
  $evm.vmdb(model, id.to_i) if model && id
end

def requested_storage(args_hash)
  vm_size = args_hash[:resource].vm_template.provisioned_storage
  args_hash[:prov_value] = args_hash[:number_of_vms] * vm_size
  request_hash_value(args_hash)
end

def request_object?(object)
  object.respond_to?('get_option')
end

def options_value(args_hash)
  return unless request_object?(args_hash[:resource])
  args_hash[:prov_value] = args_hash[:resource].get_option(args_hash[:prov_option])
  request_hash_value(args_hash)
end

def collect_totals(array)
  array.collect(&:to_i).inject(&:+).to_i
end

def collect_dialog_totals(prov_option, options_hash)
  dialog_values(prov_option, options_hash, dialog_array = [])
  collect_totals(dialog_array)
end

def dialog_values(prov_option, options_hash, dialog_array)
  args_hash = {:prov_option   => prov_option,
               :options_array => dialog_array,
               :cloud         => false}

  options_hash.each do |_sequence_id, options|
    args_hash[:prov_value] = options[prov_option]
    args_hash[:flavor] = flavor_obj(options[:instance_type])
    request_hash_value(args_hash)
  end
end

def request_hash_value(args_hash)
  return if cloud_value(args_hash)

  default_option(args_hash[:prov_value], args_hash[:options_array])
end

def provision_type(resource)
  if @service
    resource.get_option(:st_prov_type)
  else
    resource.source.try(:vendor)
  end
end

def cloud_storage(flavor, dialog_array, resource)
  return unless flavor

  storage = if provision_type(resource) == 'google'
              get_option_value(resource, :boot_disk_size).gigabytes
            else
              flavor.root_disk_size.to_i + flavor.ephemeral_disk_size.to_i + flavor.swap_disk_size.to_i
            end
  default_option(storage, dialog_array)
end

def cloud_number_of_cpus(flavor, dialog_array)
  return unless flavor
  $evm.log(:info, "Retrieving cloud flavor #{flavor.name} cpus => #{flavor.cpus}")
  default_option(flavor.cpus, dialog_array)
end

def cloud_vm_memory(flavor, dialog_array)
  return unless flavor
  $evm.log(:info, "Retrieving flavor #{flavor.name} memory => #{flavor.memory}")
  default_option(flavor.memory, dialog_array)
end

def cloud_value(args_hash)
  return false unless args_hash[:cloud]

  case args_hash[:prov_option]
  when :number_of_cpus
    cloud_number_of_cpus(args_hash[:flavor], args_hash[:options_array])
  when :vm_memory
    cloud_vm_memory(args_hash[:flavor], args_hash[:options_array])
  when :storage
    cloud_storage(args_hash[:flavor], args_hash[:options_array], args_hash[:resource])
  end
end

def default_option(option_value, options_array)
  return if option_value.blank?
  options_array << option_value.to_i
end

def service_options
  options_hash = get_dialog_options_hash(@miq_request.options[:dialog])
  @service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  $evm.log(:info, "service_template id: #{@service_template.id} service_type: #{@service_template.service_type}")
  options_hash
end

def composite_service_options_value(child_service_resource, prov_option, options_array)
  return if child_service_resource.resource.prov_type.starts_with?('generic')
  child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
    service_prov_option_value(prov_option, grandchild_service_template_service_resource.resource, options_array)
  end
end

# get_dialog_options_hash - Look for dialog variables in the dialog options hash that start with "dialog_option_[0-9]"
def get_dialog_options_hash(dialog_options)
  options_hash = Hash.new { |h, k| h[k] = {} }
  # Loop through all of the options and build an options_hash from them
  dialog_options.each do |k, v|
    if /^dialog_option_(?<sequence_id>\d*)_(?<option_key>.*)/i =~ k
      set_hash_value(sequence_id, option_key.downcase.to_sym, v, options_hash)
    else
      set_hash_value(0, k.downcase.to_sym, v, options_hash)
    end
  end
  $evm.log(:info, "Inspecting options_hash: #{options_hash.inspect}")
  options_hash
end

def set_hash_value(sequence_id, option_key, value, options_hash)
  return if value.blank?
  $evm.log(:info, "Adding seq_id: #{sequence_id} key: #{option_key.inspect} value: #{value.inspect} to options_hash")
  options_hash[sequence_id][option_key] = value
end

def error(type)
  msg = "Unable to calculate requested #{type}, due to an error getting the #{type}"
  $evm.log(:error, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

request_info
error("request") if @miq_request.nil?

options_hash = service_options if @service

if @service && !@service_template.prov_type.nil? && @service_template.prov_type.starts_with?("generic")
  $evm.log(:info, "Generic Service Item.  No quota check being done.")
  $evm.root['ae_result'] = 'ok'
  $evm.root['ae_next_state'] = 'finished'
  exit MIQ_OK
end

$evm.root['quota_requested'] = calculate_requested(options_hash)
