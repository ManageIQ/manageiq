
def vmdb_object_from_array_entry(entry)
  model, id = entry.split("::")
  $evm.vmdb(model, id.to_i) if model && id
end

def parent_task(task)
  return task if task.miq_request_task.nil?
  parent_task(task.miq_request_task)
end

def add_hash_value(sequence_id, option_key, value, hash)
  $evm.log("info", "Adding seq_id: #{sequence_id} key: #{option_key} value: #{value} ")
  hash[sequence_id][option_key] = value
end

def process_comma_separated_object_array(sequence_id, option_key, value, hash)
  return if value.nil?
  options_value_array = []
  value.split(",").each do |entry|
    vmdb_obj = vmdb_object_from_array_entry(entry)
    next if vmdb_obj.nil?
    options_value_array << (vmdb_obj.respond_to?(:name) ? vmdb_obj.name : "#{vmdb_obj.class.name}::#{vmdb_obj.id}")
  end
  hash[sequence_id][option_key] = options_value_array
end

def option_hash_value(dialog_key, dialog_value, options_hash)
  return false unless /^dialog_option_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
  add_hash_value(sequence.to_i, option_key.to_sym, dialog_value, options_hash)
  true
end

def option_array_value(dialog_key, dialog_value, options_hash)
  return false unless /^array::dialog_option_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
  process_comma_separated_object_array(sequence.to_i, option_key.to_sym, dialog_value, options_hash)
  true
end

def tag_hash_value(dialog_key, dialog_value, tags_hash)
  return false unless /^dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
  add_hash_value(sequence.to_i, option_key.to_sym, dialog_value, tags_hash)
  true
end

def tag_array_value(dialog_key, dialog_value, tags_hash)
  return false unless /^array::dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
  process_comma_separated_object_array(sequence.to_i, option_key.to_sym, dialog_value, tags_hash)
  true
end

def generic_dialog_value(dialog_key, dialog_value, options_hash)
  return false unless /^dialog_(?<option_key>.*)/i =~ dialog_key
  add_hash_value(0, option_key.to_sym, dialog_value, options_hash)
  true
end

def parse_dialog_entries(dialog_options)
  options_hash        = Hash.new { |h, k| h[k] = {} }
  tags_hash           = Hash.new { |h, k| h[k] = {} }

  dialog_options.each do |key, value|
    next if value.blank?

    option_hash_value(key, value, options_hash) ||
      option_array_value(key, value, options_hash) ||
      tag_hash_value(key, value, tags_hash) ||
      tag_array_value(key, value, tags_hash) ||
      generic_dialog_value(key, value, options_hash)
  end
  return options_hash, tags_hash
end

def parent_task_dialog_information(task)
  bundle_task = parent_task(task)
  if bundle_task.nil?
    $evm.log('error', "Unable to locate Dialog information")
    exit MIQ_ABORT
  end

  $evm.log('info', "Current task has empty dialogs, getting dialog information from parent task")
  options_hash = YAML.load(bundle_task.get_option(:parsed_dialog_options))
  tags_hash = YAML.load(bundle_task.get_option(:parsed_dialog_tags))
  return options_hash, tags_hash
end

def save_parsed_dialog_information(options_hash, tags_hash, task)
  task.set_option(:parsed_dialog_options, YAML.dump(options_hash))
  task.set_option(:parsed_dialog_tags, YAML.dump(tags_hash))
  $evm.log('info', "parsed_dialog_options: #{task.get_option(:parsed_dialog_options).inspect}")
  $evm.log('info', "parsed_dialog_tags: #{task.get_option(:parsed_dialog_tags).inspect}")
end

task = $evm.root['service_template_provision_task']

dialog_entries = task.dialog_options

$evm.log('info', "dialog_options: #{dialog_entries.inspect}")

options_hash, tags_hash = parse_dialog_entries(dialog_entries)

if options_hash.blank? && tags_hash.blank?
  options_hash, tags_hash = parent_task_dialog_information(task)
else
  $evm.log('info', "Current task has dialog information")
end

save_parsed_dialog_information(options_hash, tags_hash, task)
