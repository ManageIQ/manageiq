#
#
# Description: This method sets the dialog optioms in the destination service and service catalog items.
# 1. Look for all Service Dialog Options in the service_template_provision_task.dialog_options
#    (i.e. Options that come from a Service Dialog)
# 2. Any Service dialog option keys that match the regular expression /^tag_0_(.*)/i will be used to
#    tag the destination Service
# 3. Service dialog option keys that match the regular expression /^(option|tag)_(\d*)_(.*)/
#    (I.e. <option_type>_<sequence_id>_variable,  option_0_vm_memory, tag_1_environment) are sorted
#    by sequence_id into an options_hash[sequence_id] and then distributed to the appropriate
#    child catalog items. For example, a sequence_id of 0 means that all catalog items will inhereit
#    these variables. A sequence_id of 1 means that the variable is only intended for a catalog item
#    with a group index of 1.
# 4. Service dialog option keys that do NOT match the regular expression are then inserted into the
#    options_hash[0] for all catalog items.
#
# Inputs: $evm.root['service_template_provision_task'].dialog_options
#

# Description: Look for service dialog variables in the root object that start with "dialog_option_[0-9]",
def get_options_hash(dialog_options)
  # Setup regular expression for service dialog tags
  options_regex = /^(dialog_option|dialog_tag)_(\d*)_(.*)/i
  options_hash = {}

  # Loop through all of the options and build an options_hash from them
  dialog_options.each do |k, v|

    option_key = k.downcase.to_sym
    if options_regex =~ k
      sequence_id = Regexp.last_match[2].to_i

      unless v.blank?
        $evm.log("info", "Adding sequence_id:<#{sequence_id}> option_key:<#{option_key.inspect}> v:<#{v.inspect}> to options_hash")
        if options_hash.key?(sequence_id)
          options_hash[sequence_id][option_key] = v
        else
          options_hash[sequence_id] = {option_key => v}
        end
      end
    else
      # If options_regex does not match then stuff dialog options into options_hash[0]
      sequence_id = 0
      unless v.nil?
        $evm.log("info", "Adding sequence_id:<#{sequence_id}> option_key:<#{option_key.inspect}> v:<#{v.inspect}> to options_hash")
        if options_hash.key?(sequence_id)
          options_hash[sequence_id][option_key] = v
        else
          options_hash[sequence_id] = {option_key => v}
        end
      end
    end # if options_regex =~ k
  end # dialog_options.each do
  $evm.log("info", "Inspecting options_hash:<#{options_hash.inspect}>")
  options_hash
end

# Description: Look for tags with a sequence_id of 0 and tag the parent service
def tag_parent_service(service, options_hash)
  # Setup regular expression for service dialog tags
  tags_regex = /^dialog_tag_0_(.*)/i

  # Look for tags with a sequence_id of 0 to tag the destination Service
  options_hash[0].each do |k, v|
    $evm.log("info", "Processing Tag Key:<#{k.inspect}> Value:<#{v.inspect}>")
    if tags_regex =~ k
      # Convert key to symbol
      tag_category = Regexp.last_match[1]
      tag_value = v.downcase
      unless tag_value.blank?
        $evm.log("info", "Adding tag_category:<#{tag_category.inspect}> value:<#{tag_value.inspect}> to Service:<#{service.name}>")
        service.tag_assign("#{tag_category}/#{tag_value}")
      end
    end # if tags_regex
  end # options_hash[0].each
end

# Get the task object from root
service_template_provision_task = $evm.root['service_template_provision_task']

# Get destination service object
service = service_template_provision_task.destination
$evm.log("info", "Detected Service:<#{service.name}> Id:<#{service.id}>")

# Get dialog options from options hash
# I.e. {:dialog=>{"option_0_myvar"=>"myprefix", "option_1_vservice_workers"=>"2", "tag_0_environment"=>"test", "tag_0_location"=>"paris",
# "option_2_vm_memory"=>"2048", "option_0_vlan"=>"Internal", "option_1_cores_per_socket"=>"1"}}
dialog_options = service_template_provision_task.dialog_options
$evm.log("info", "Inspecting Dialog Options:<#{dialog_options.inspect}>")

# Get options_hash
options_hash = get_options_hash(dialog_options)

# Tag Parent Service
tag_parent_service(service, options_hash)

# Process Child Services
service_template_provision_task.miq_request_tasks.each do |t|
  # Child Service
  child_service = t.destination
  # Service Bundle Resource
  child_service_resource = t.service_resource

  # Increment the provision_index number since the child resource starts with a zero
  group_idx = child_service_resource.provision_index + 1
  $evm.log("info", "Child service name:<#{child_service.name}> group_idx:<#{group_idx}>")

  # Create dialog options hash variable
  dialog_options_hash = {}

  # Set all dialog options pertaining to the catalog item plus any options destined for the catalog bundle
  unless options_hash[0].nil?
    unless options_hash[group_idx].nil?
      # Merge child options with global options if any
      dialog_options_hash = options_hash[0].merge(options_hash[group_idx])
    else
      dialog_options_hash = options_hash[0]
    end
  else # unless options_hash[0].nil?
    unless options_hash[group_idx].nil?
      dialog_options_hash = options_hash[group_idx]
    end
  end

  # Pass down dialog options to catalog items
  dialog_options_hash.each do |k, v|
    $evm.log("info", "Adding Dialog Option:<{#{k.inspect} => #{v.inspect}}> to Child Service:<#{child_service.name}>")
    t.set_dialog_option(k, v)
  end
  $evm.log("info", "Inspecting Child Service:<#{child_service.name}> Dialog Options:<#{t.dialog_options.inspect}>")
end
