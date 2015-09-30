#
# Description: <Method description here>
#
def request_info
  @service = ($evm.object['quota_type'] == 'service') ? true : false
  @miq_request = $evm.root['miq_request']
  $evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")
end

def calculate_requested(options_hash = {})
  {:memory            => get_total_requested(options_hash, :vm_memory),
   :cpu               => get_total_requested(options_hash, :cores_per_socket),
   :allocated_storage => get_total_requested(options_hash, :allocated_storage),
   :vms               => get_total_requested(options_hash, :number_of_vms)}
end

def get_total_requested(options_hash, prov_option)
  total_requested = collect_template_totals(prov_option)
  total_requested = request_totals(total_requested.to_i,
                                   collect_dialog_totals(prov_option, options_hash).to_i) if options_hash
  total_requested
end

def request_totals(template_totals, dialog_totals)
  template_totals < dialog_totals ? dialog_totals : template_totals
end

def collect_template_totals(prov_option)
  total = collect_totals(service_prov_option_value(prov_option)) if @service
  total = collect_totals(vm_prov_option_value(prov_option)) unless @service
  total
end

def get_option_value(request, option)
  request.get_option(option).to_i
end

def service_prov_option_value(prov_option, options_array = [])
  @service_template.service_resources.each do |child_service_resource|
    if @service_template.service_type == 'composite'
      composite_service_options_value(child_service_resource, prov_option, options_array)
    else
      next if @service_template.prov_type.starts_with?("generic")
      options_value(prov_option, child_service_resource.resource, options_array)
    end
  end
  options_array
end

def vm_prov_option_value(prov_option, options_array = [])
  number_of_vms = get_option_value(@miq_request, :number_of_vms)
  case prov_option
  when :vm_memory
    set_requested_value(prov_option, memory_in_request(number_of_vms),
                        @miq_request.get_option(:instance_type), options_array)
  when :number_of_cpus
    set_requested_value(prov_option, cpu_in_request,
                        @miq_request.get_option(:instance_type), options_array)
  when :allocated_storage
    set_requested_value(prov_option, storage_in_request(number_of_vms),
                        @miq_request.get_option(:instance_type), options_array)
  else
    options_value(prov_option, @miq_request, options_array)
  end
  options_array
end

def storage_in_request(number_of_vms)
  vm_size = @miq_request.vm_template.provisioned_storage
  vm_size = get_option_value(@miq_request, :allocated_storage) if vm_size.zero?
  number_of_vms * vm_size
end

def cpu_in_request
  cpu_in_request = get_option_value(@miq_request, :number_of_cpus)
  return cpu_in_request unless cpu_in_request.zero?
  get_option_value(@miq_request, :number_of_sockets) * get_option_value(@miq_request, :cores_per_socket)
end

def memory_in_request(number_of_vms)
  memory_in_request = number_of_vms * get_option_value(@miq_request, :vm_memory)
end

def options_value(prov_option, resource, options_array)
  return unless resource.respond_to?('get_option')
  set_requested_value(prov_option, resource.get_option(prov_option),
                      resource.get_option(:instance_type), options_array)
end

def collect_totals(array)
  array.collect(&:to_i).inject(&:+).to_i
end

def collect_dialog_totals(prov_option, options_hash)
  dialog_values(prov_option, options_hash, dialog_array = [])
  collect_totals(dialog_array)
end

def request_totals(template_totals, dialog_totals)
  template_totals < dialog_totals ? dialog_totals : template_totals
end

def dialog_values(prov_option, options_hash, dialog_array)
  options_hash.each do |_sequence_id, options|
    set_requested_value(prov_option, options[prov_option], options[:instance_type], dialog_array)
  end
end

def set_requested_value(prov_option, option_value, find_id, dialog_array)
  $evm.log(:info, "set requested value: prov_option: #{prov_option} value:  #{option_value}")
  return if cloud_value(prov_option, option_value, find_id, dialog_array)

  $evm.log(:info, "set requested value default_option: prov_option: #{prov_option} value:  #{option_value}")
  default_option(option_value, dialog_array)
end

def cloud_value(prov_option, option_value, find_id, dialog_array)
  return nil unless @cloud

  case prov_option
  when :cores_per_socket
    $evm.log(:info, "set requested value cores_per_socket: prov_option: #{prov_option} value:  #{option_value}")
    option_set = requested_cores_per_socket(find_id, dialog_array)
  when :vm_memory
    $evm.log(:info, "set requested value vm_memory: prov_option: #{prov_option} value:  #{option_value}")
    option_set = requested_vm_memory(find_id, dialog_array)
  when :allocated_storage
    $evm.log(:info, "set requested value allocated_storage: prov_option: #{prov_option} value:  #{option_value}")
    option_set = requested_allocated_storage(@miq_request.get_option(:src_vm_id), dialog_array)
  end
  option_set
end

def default_option(option_value, options_array)
  return if option_value.blank?
  options_array << option_value.to_i
end

def service_options
  options_hash = get_dialog_options_hash(@miq_request.options[:dialog])
  @service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  $evm.log(:info, "service_template id: #{@service_template.id} service_type: #{@service_template.service_type}")
  $evm.log(:info, "services: #{@service_template.service_resources.count}")
  options_hash
end

def composite_service_options_value(child_service_resource, prov_option, options_array)
  return if child_service_resource.resource.prov_type == 'generic'
  child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
    options_value(prov_option, grandchild_service_template_service_resource.resource, options_array)
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
  msg = "Unable to calculate requested due to an error getting the #{type}"
  $evm.log(:warn, " #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

request_info
error("request") if @miq_request.nil?

options_hash = service_options if @service

$evm.root['quota_requested'] = calculate_requested(options_hash)
