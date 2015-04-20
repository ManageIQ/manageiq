#
# Description: Tag service and set provison options based on service dialog entries.
# 1. Look for all Service Dialog Options in the service_template_provision_task.dialog_options
#    (i.e. Dialog options that came from either a Catalog Bundle Service or a Service Dialog)
# 2. Service dialog option keys that match the regular expression /^tag_\d*_(.*)/i
#    (I.e. <tag>_<sequence_id>_variable,  tag_0_function, tag_1_environment) will be used to
#    tag the destination Catalog Item Service and any subordinate miq_provision tasks
# 3. The remaining Service Dialog Option keys are simply passed into the subordinate
#    miq_provision object. I.e. option_0_vm_memory => 2048
#
# Inputs: $evm.root['service_template_provision_task'].dialog_options
#

# array_entry example - Classification::1
def vmdb_object_from_array_entry(entry)
  model, id = entry.split("::")
  $evm.vmdb(model, id.to_i) if model && id
end

def array_value(hash, hash_key, value)
  if hash.key?(hash_key)
    values = hash[hash_key]
    values = "#{values},#{value}"
    values[0] = "" if values[0] == ","
  else
    value
  end
end

def get_tags_hash(dialog_options)
  # Setup regular expressions for service dialog tags
  tags_regex       = /^dialog_tag_\d*_(.*)/
  tags_array_regex = /^Array::dialog_tag_\d*_(.*)/
  tags_hash        = {}

  # Loop through all of the tags and build an options_hash from them
  dialog_options.each do |key, value|
    next if value.blank?

    if tags_regex =~ key
      tag_category = Regexp.last_match[1].to_sym
      tag_value = value.downcase
      $evm.log("info", "Adding category:<#{tag_category.inspect}> tag:<#{tag_value.inspect}> to tags_hash")
      tags_hash[tag_category] = tag_value
    # Classification::1,Classification::2
    elsif tags_array_regex =~ key
      tag_category = Regexp.last_match[1].to_sym
      value.split(",").each do |entry|
        vmdb_obj = vmdb_object_from_array_entry(entry)
        next if vmdb_obj.blank?
        tag_value = array_value(tags_hash, tag_category, vmdb_obj.to_tag)
        next if tag_value.blank?
        tags_hash[tag_category] = tag_value
        $evm.log("info", "Adding category:<#{tag_category.inspect}> tag:<#{tag_value.inspect}> to tags_hash")
      end
    end
  end
  $evm.log("info", "Inspecting tags_hash:<#{tags_hash.inspect}>")
  tags_hash
end

# Look for service dialog variables in the dialog options hash that start with "option_[0-9]",
def get_options_hash(dialog_options)
  # Setup regular expression for service dialog tags
  options_regex       = /^dialog_option_\d*_(.*)/
  options_array_regex = /^Array::dialog_option_\d*_(.*)/
  options_hash        = {}

  # Loop through all of the options and build an options_hash from them
  dialog_options.each do |key, value|
    if options_regex =~ key
      option_key = Regexp.last_match[1].to_sym
      option_value = value

      unless option_value.blank?
        $evm.log("info", "Adding key:<#{option_key.inspect}> value:<#{option_value.inspect}>")
        options_hash[option_key] = option_value
      end
    elsif options_array_regex =~ key
      option_key = Regexp.last_match[1].to_sym
      value.split(",").each do |entry|
        vmdb_obj = vmdb_object_from_array_entry(entry)
        next if vmdb_obj.blank?

        option_value = array_value(options_hash, option_key, vmdb_obj.description)
        options_hash[option_key] = option_value unless option_value.blank?
        $evm.log("info", "Adding key:<#{option_key.inspect}> value:<#{option_value.inspect}> to options_hash")
      end
    else
      unless value.nil?
        $evm.log("info", "Adding option:<#{key.to_sym.inspect}> value:<#{value.inspect}> to options_hash")
        options_hash[key.to_sym] = value
      end
    end
  end
  options_hash
end

# Look in tags_hash for tags and tag the service
def tag_service(service, tags_hash)
  unless tags_hash.nil?
    tags_hash.each do |_k, v|
      v.split(",").each do |e|
        $evm.log("info", "Adding Tag:<#{e}> to Service:<#{service.name}>")
        service.tag_assign("#{e.downcase}")
      end
      $evm.log("info", "service tags: <#{service.tags}")
    end
  end
end

# Get the task object from root
service_template_provision_task = $evm.root['service_template_provision_task']

# Get destination service object
service = service_template_provision_task.destination
$evm.log("info", "Detected Service:<#{service.name}> Id:<#{service.id}>")

# Get dialog options from options hash
# {:dialog=>{"option_0_myvar"=>"myprefix", "option_1_vservice_workers"=>"2", "tag_0_environment"=>"test",
# "tag_0_location"=>"paris", # "option_2_vm_memory"=>"2048", "option_0_vlan"=>"Internal",
# "option_1_cores_per_socket"=>"1"}}
dialog_options = service_template_provision_task.dialog_options
$evm.log("info", "Inspecting Dialog Options:<#{dialog_options.inspect}>")

# Get tags_hash
tags_hash = get_tags_hash(dialog_options)

# Tag Service
tag_service(service, tags_hash)

# Get options_hash
options_hash = get_options_hash(dialog_options)

# Process Child Tasks
service_template_provision_task.miq_request_tasks.each do |t|

  # Process grandchildren service options
  unless t.miq_request_tasks.nil?
    grandchild_tasks = t.miq_request_tasks
    grandchild_tasks.each do |gc|
      $evm.log("info", "Detected Task ID:<#{gc.id}> Desc:<#{gc.description}> source type:<#{gc.source_type}>")

      # If child task is provisioning then apply tags and options
      if gc.source_type == "template"
        unless tags_hash.nil?
          tags_hash.each do |k, v|
            v.split(",").each do |e|
              $evm.log("info", "Adding Tag:<#{e}> to Provisioning ID:<#{gc.id}>")
              gc.add_tag(k, e)
            end
          end
        end
        unless options_hash.nil?
          options_hash.each do |k, v|
            $evm.log("info", "Adding Option:<{#{k.inspect} => #{v.inspect}}> to Provisioning ID:<#{gc.id}>")
            gc.set_option(k, v)
          end
        end
      else
        $evm.log("info", "Invalid Source Type:<#{gc.source_type}>. Skipping task ID:<#{gc.id}>")
      end # if gc.source_type
    end # grandchild_tasks.each do
  end # unless t.miq_request_tasks.nil?
end # service_template_provision_task.miq_request_tasks.each do
