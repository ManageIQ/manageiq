
def request_info
  type = $evm.object['quota_type']
  if type == 'service'
    @service = true
    @miq_request = $evm.root['service_template_provision_request']
  else
    @miq_request = $evm.root['miq_request']
    @service = false
  end
  $evm.log(:info, "Request: #{@miq_request.description} id: #{@miq_request.id} ")
end

def entity_info
  user = @miq_request.requester
  $evm.log(:info, "Quota Entity: #{user.current_group.description}")
  @entity = user.current_group
end

def vmdb_object(object, id)
  $evm.vmdb(object).find_by_id(id)
end

def model_value(attr, unit)
  value = $evm.object[attr].to_i
  $evm.log(:info, "Quota Model #{attr}: #{value} #{unit}") unless value.zero?
  value
end

def tag_value(tag, tag_value, unit)
  value = tag_value.to_i
  $evm.log(:info, "Quota Tag #{tag}: #{value} #{unit}") unless value.zero?
  value
end

def get_option_value(request, option)
  request.get_option(option).to_i
end

def manage_quotas_by_group?
  # specify whether quotas should be managed (valid options are [true | false])
  manage_quotas_by_group = $evm.object['manage_quotas_by_group'] || true
  manage_quotas_by_group =~ (/(true|t|yes|y|1)$/i)
  true
end

def get_total_requested(options_hash, prov_option)
  total_requested = collect_template_totals(prov_option)
  total_requested = request_totals(total_requested.to_i,
                                   collect_dialog_totals(prov_option, options_hash).to_i) if options_hash
  total_requested
end

def collect_template_totals(prov_option)
  total = collect_totals(service_prov_option_value(prov_option)) if @service
  total = collect_totals(vm_prov_option_value(prov_option)) unless @service
  total
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

def quota_check(args_hash)
  return unless quota_exceeded?(args_hash[:used].to_i, args_hash[:requested].to_i, args_hash[:limit].to_i)
  quota_exceeded(args_hash, :item, reason(args_hash))
end

def quota_exceeded?(used, requested, quota)
  if used + requested > quota
    $evm.log(:info, "Quota exceeded: Used(#{used}) + Requested(#{requested}) > Quota(#{quota})")
    return true
  end
  false
end

def quota_exceeded(args_hash, quota_hash_key, reason)
  args_hash[:warn] ? (@quota_results[:quota_warn_exceeded] = true) : (@quota_results[:quota_exceeded] = true)
  $evm.log(:info,  "Quota Limit exceeded for key: #{args_hash[quota_hash_key]} reason: #{reason}") if @quota_results[:quota_exceeded]
  $evm.log(:info,  "Quota Warning exceeded for key: #{args_hash[quota_hash_key]} reason: #{reason}") if @quota_results[:quota_warn_exceeded]
  @quota_results[args_hash[quota_hash_key].to_sym] = reason
  true
end

def reason(args_hash)
  "#{args_hash[:item]} - #{args_hash[:used]} #{args_hash[:unit]} plus requested " \
  "#{args_hash[:requested]} #{args_hash[:unit]} &gt; quota #{args_hash[:limit]} #{args_hash[:unit]}"
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

def composite_service_options_value(child_service_resource, prov_option, options_array)
  return if child_service_resource.resource.prov_type == 'generic'
  child_service_resource.resource.service_resources.each do |grandchild_service_template_service_resource|
    options_value(prov_option, grandchild_service_template_service_resource.resource, options_array)
  end
end

def vm_prov_option_value(prov_option, options_array = [])
  number_of_vms = get_option_value(@miq_request, :number_of_vms)
  case prov_option
  when :vm_memory
    memory_in_request = number_of_vms * get_option_value(@miq_request, :vm_memory)
    set_requested_value(prov_option, memory_in_request,
                       @miq_request.get_option(:instance_type), options_array)
  when :number_of_cpus
    cpu_in_request = get_option_value(@miq_request, :number_of_cpus)
    if cpu_in_request.zero?
      cpu_in_request = get_option_value(@miq_request, :number_of_sockets) *
                       get_option_value(@miq_request, :cores_per_socket)
    end
    set_requested_value(prov_option, cpu_in_request,
                        @miq_request.get_option(:instance_type), options_array)
  when :allocated_storage
    vm_size = @miq_request.vm_template.provisioned_storage
    total_storage = number_of_vms * vm_size
    set_requested_value(prov_option, total_storage,
                        @miq_request.get_option(:instance_type), options_array)
  else
    options_value(prov_option, @miq_request, options_array)
  end
  options_array
end

def dialog_values(prov_option, options_hash, dialog_array)
  options_hash.each do |_sequence_id, options|
    set_requested_value(prov_option, options[prov_option], options[:instance_type], dialog_array)
  end
end

def options_value(prov_option, resource, options_array)
  return unless resource.respond_to?('get_option')
  set_requested_value(prov_option, resource.get_option(prov_option),
                       resource.get_option(:instance_type), options_array)
end

def default_option(option_value, options_array)
  return if option_value.blank?
  options_array << option_value.to_i
end

def calculate_requested(options_hash = {})
  @requested_hash = {:memory            => get_total_requested(options_hash, :vm_memory),
                     :cpu               => get_total_requested(options_hash, :cores_per_socket),
                     :allocated_storage => get_total_requested(options_hash, :allocated_storage),
                     :vms               => get_total_requested(options_hash, :number_of_vms)}
end

def set_requested_value(prov_option, option_value, find_id, dialog_array)
  $evm.log(:info,  "set requested value: prov_option: #{prov_option} value:  #{option_value}")
  case prov_option
  when :cores_per_socket
  $evm.log(:info,  "set requested value cores_per_socket: prov_option: #{prov_option} value:  #{option_value}")
    option_set = requested_cores_per_socket(find_id, dialog_array)
  when :vm_memory
  $evm.log(:info,  "set requested value vm_memory: prov_option: #{prov_option} value:  #{option_value}")
    option_set = requested_vm_memory(find_id, dialog_array)
  when :allocated_storage
  $evm.log(:info,  "10 set requested value allocated_storage: prov_option: #{prov_option} value:  #{option_value}")
    src_id = @miq_request.get_option(:src_vm_id)
    $evm.log(:info,  "20 XXXXXXX set requested value allocated_storage: prov_option: #{prov_option} src_id:  #{src_id}")
    option_set = requested_allocated_storage(@miq_request.get_option(:src_vm_id), dialog_array)
  end
  return if option_set
  $evm.log(:info,  "set requested value default_option: prov_option: #{prov_option} value:  #{option_value}")
  default_option(option_value, dialog_array)
end

def requested_cores_per_socket(vmdb_object_find_by, options_array)
  flavor = $evm.vmdb(:flavor).find_by_id(vmdb_object_find_by)
  return false unless flavor

  options_array << flavor.cpus
  true
end

def requested_allocated_storage(vmdb_object_find_by, options_array)
  $evm.log(:info,  "1 requested allocated storage: id: #{vmdb_object_find_by} options_array:  #{options_array}")
  template = vmdb_object(:miq_template, vmdb_object_find_by)
  return false unless template

  $evm.log(:info,  "2 requested allocated storage: id: #{vmdb_object_find_by} options_array:  #{options_array}")
  options_array << template.provisioned_disk_storage
  true
end

def requested_vm_memory(vmdb_object_find_by, options_array)
  flavor = vmdb_object(:flavor, vmdb_object_find_by)
  return false unless flavor

  flavor_memory = flavor.memory / 1024**2
  options_array << flavor_memory
  true
end

def check_quotas
  used = consumption
  return unless used

  memory_quota_check(used[:memory], @requested_hash[:memory])

  cpu_quota_check(used[:cpu], @requested_hash[:cpu])

  storage_quota_check(used[:allocated_storage], @requested_hash[:allocated_storage])

  vm_quota_check(used[:vms], @requested_hash[:vms])
end

def memory_quota_check(used, requested)
  $evm.log(:info, "Memory Quota Check Starting")
  $evm.log(:info, "Requested memory: #{requested} MB")
  item_hash = {:type            => :memory,
               :title           => "vRAM",
               :model_attribute => "max_group_memory",
               :tag_name        => :quota_max_memory,
               :requested       => requested,
               :warn            => false,
               :reason_key      => "group_memory_quota_exceeded",
               :unit            => "MB"}

  if quota_item_check(item_hash, used, requested)
    $evm.log(:info, "Memory Quota Check Failed")
    return
  end
  $evm.log(:info, "Memory Quota Check passed, checking quota warning.")

  item_hash[:model_attribute] = "warn_group_memory"
  item_hash[:tag_name] = :quota_warn_memory
  item_hash[:warn] = true
  item_hash[:reason_key] = "group_warn_memory_quota_exceeded"

  warn_exceeded = quota_item_check(item_hash, used, requested)
  $evm.log(:info, "Memory Quota Warning Check Failed") if warn_exceeded
  $evm.log(:info, "Memory Quota Warning Check Passed") unless warn_exceeded
end

def cpu_quota_check(used, requested)
  $evm.log(:info, "CPU Quota Check")
  $evm.log(:info, "Requested cpu: #{requested}")
  item_hash = {:type            => :cpu,
               :title           => "vCPU",
               :model_attribute => "max_group_cpu",
               :tag_name        => :quota_max_cpu,
               :requested       => requested,
               :warn            => false,
               :reason_key      => "group_cpu_quota_exceeded",
               :unit            => nil}

  if quota_item_check(item_hash, used, requested)
    $evm.log(:info, "CPU Quota Check Failed")
    return
  end
  $evm.log(:info, "CPU Quota Check passed, checking quota warning.")

  item_hash[:model_attribute] = "warn_group_cpu"
  item_hash[:tag_name] = :quota_warn_cpu
  item_hash[:warn] = true
  item_hash[:reason_key] = "group_warn_cpu_quota_exceeded"

  warn_exceeded = quota_item_check(item_hash, used, requested)
  $evm.log(:info, "CPU Quota Warning Check Failed") if warn_exceeded
  $evm.log(:info, "CPU Quota Warning Check Passed") unless warn_exceeded
end

def vm_quota_check(used, requested)
  $evm.log(:info, "VM Quota Check")
  $evm.log(:info, "Requested vms: #{requested}")
  item_hash = {:type            => :vms,
               :title           => "VMs",
               :model_attribute => "max_group_vms",
               :tag_name        => :quota_max_vms,
               :requested       => requested,
               :warn            => false,
               :reason_key      => "group_vms_quota_exceeded",
               :unit            => nil}

  if quota_item_check(item_hash, used, requested)
    $evm.log(:info, "VM Quota Check Failed")
    return
  end
  $evm.log(:info, "VM Quota Check passed, checking quota warning.")

  item_hash[:model_attribute] = "warn_group_vms"
  item_hash[:tag_name] = :quota_warn_vms
  item_hash[:warn] = true
  item_hash[:reason_key] = "group_warn_vms_quota_exceeded"

  warn_exceeded = quota_item_check(item_hash, used, requested)
  $evm.log(:info, "VM Quota Warning Check Failed") if warn_exceeded
  $evm.log(:info, "VM Quota Warning Check Passed") unless warn_exceeded
end

def storage_quota_check(used, requested)
  $evm.log(:info, "Storage Quota Check")
  $evm.log(:info, "Requested storage: #{requested}")

  item_hash = {:type            => :allocated_storage,
               :title           => "storage",
               :model_attribute => "max_group_storage",
               :tag_name        => :quota_max_storage,
               :requested       => requested,
               :warn            => false,
               :reason_key      => "group_storage_quota_exceeded",
               :unit            => "bytes"}

  if quota_item_check(item_hash, used, requested)
    $evm.log(:info, "Storage Quota Check Failed")
    return
  end
  $evm.log(:info, "Storage Quota Check passed, checking quota warning.")

  item_hash[:model_attribute] = "warn_group_storage"
  item_hash[:tag_name] = :quota_warn_storage
  item_hash[:warn] = true
  item_hash[:reason_key] = "group_warn_storage_quota_exceeded"

  warn_exceeded = quota_item_check(item_hash, used, requested)
  $evm.log(:info, "Storage Quota Warning Check Failed") if warn_exceeded
  $evm.log(:info, "Storage Quota Warning Check Passed") unless warn_exceeded
end

def quota_item_check(item_hash, used, requested)
  $evm.log(:info, "Used #{item_hash[:type]}: #{used} #{item_hash[:unit]}")
  limit = quota_values(item_hash, item_hash[:unit])
  args_hash = {:used      => used,
               :requested => requested,
               :limit     => limit,
               :unit      => item_hash[:unit],
               :warn      => item_hash[:warn],
               :item      => item_hash[:reason_key]}
  quota_check(args_hash) unless limit.zero?
end

def quota_values(item_hash, unit)
  object_value = quota_model_value(item_hash[:model_attribute], unit)
  tag_value = tag_value(item_hash[:tag_name], @entity.tags(item_hash[:tag_name]).first, unit)
  final_quota_value(tag_value, object_value)
end

def quota_model_value(model_attr, unit)
  model_value(model_attr, unit)
end

def final_quota_value(tag_quota_value, object_quota_value)
  tag_quota_value.zero? ? object_quota_value : tag_quota_value
end

def consumption
  {
    :cpu                 => @entity.allocated_vcpu,
    :memory              => @entity.allocated_memory / 1024**2,
    :vms                 => @entity.vms.count { |vm| vm.id unless vm.archived },
    :allocated_storage   => @entity.allocated_storage / 1024**2,
    :provisioned_storage => @entity.provisioned_storage / 1024**2
  }
end

def service_options
  options_hash = get_dialog_options_hash(@miq_request.options[:dialog])
  @service_template = $evm.vmdb(@miq_request.source_type, @miq_request.source_id)
  $evm.log(:info, "service_template id: #{@service_template.id} service_type: #{@service_template.service_type}")
  $evm.log(:info, "services: #{@service_template.service_resources.count}")
  options_hash
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

def check_quota_results
  if @quota_results[:quota_exceeded]
    quota_exceeded_message('limit')
    $evm.root['ae_result'] = 'error'
  elsif @quota_results[:quota_warn_exceeded]
    quota_exceeded_message('threshold')
    $evm.root['ae_result'] = 'ok'
    # send a warning message that quota threshold is close
    # $evm.instantiate('/Service/Provisioning/Email/ServiceTemplateProvisionRequest_Warning') if @service
  end
end

def quota_exceeded_message(type)
  err_message = nil
  case type
  when 'limit'
    err_message = message_text(nil, "Request denied due to the following quota limits: ")
  end
  warn_message = message_text('warn_', "Request warning due to the following quota thresholds: ")

  $evm.log(:info, "Quota Error Message: #{err_message}") if err_message
  $evm.log(:info, "Quota Warning Message: #{warn_message}") if warn_message
  message = err_message + warn_message
  @miq_request.set_message(message[0..250])
  @miq_request.set_option("service_quota_#{warn}exceeded".to_sym, message)
end

def message_text(type, msg)
  message = msg
  ["group_#{type}cpu_quota_exceeded".to_sym,
   "group_#{type}memory_quota_exceeded".to_sym,
   "group_#{type}storage_quota_exceeded".to_sym,
   "group_#{type}vms_quota_exceeded".to_sym].each do |q|
    message += "(#{@quota_results[q]}) " if @quota_results[q]
  end
  message
end

def setup
  @quota_results = {:quota_exceeded => false, :quota_warn_exceeded => false}
end

def error(type)
  msg = "Unable to calculate quota due to an error getting the #{type}"
  $evm.log(:warn," #{msg}")
  $evm.root['ae_result'] = 'error'
  raise msg
end

$evm.log(:warn, "Quota Processing starting.")

unless manage_quotas_by_group?
  $evm.log(:warn, "Quota is turned off. ")
  return
end

$evm.log("info", "Listing Root Object Attributes:")
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
$evm.log("info", "===========================================")


setup

request_info
error("request") if @miq_request.nil?

entity_info
error("entity") if @entity.nil?

options_hash = service_options if @service

calculate_requested(options_hash)

check_quotas

check_quota_results
