class DialogParser
  def initialize(handle)
    @handle = handle
    @options_hash  = Hash.new { |h, k| h[k] = {} }
    @tags_hash     = Hash.new { |h, k| h[k] = {} }
  end

  def main
    stp_request = @handle.root['service_template_provision_request']

    dialog_entries = stp_request.options[:dialog]

    @handle.log('info', "dialog_options: #{dialog_entries.inspect}")

    parse_dialog_entries(dialog_entries)

    save_parsed_dialog_information(stp_request)
  end

  private

  def parse_dialog_entries(dialog_options)
    dialog_options.each do |key, value|
      next if value.blank?
      set_dialog_value(key, value)
    end
  end

  def save_parsed_dialog_information(miq_request)
    miq_request.set_option(:parsed_dialog_options, YAML.dump(merge_hash(@options_hash)))
    miq_request.set_option(:parsed_dialog_tags, YAML.dump(merge_hash(@tags_hash)))
    @handle.log('info', "parsed_dialog_options: #{miq_request.get_option(:parsed_dialog_options).inspect}")
    @handle.log('info', "parsed_dialog_tags: #{miq_request.get_option(:parsed_dialog_tags).inspect}")
  end

  def vmdb_object_from_array_entry(entry)
    model, id = entry.split("::")
    @handle.vmdb(model, id.to_i) if model && id
  end

  def add_hash_value(sequence_id, option_key, value, hash)
    @handle.log("info", "Adding seq_id: #{sequence_id} key: #{option_key} value: #{value} ")
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

  def option_password_value(dialog_key, dialog_value)
    return false unless /^password::dialog_option_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
    add_password_value(sequence.to_i, option_key, dialog_value)
    true
  end

  def generic_password_value(dialog_key, dialog_value)
    return false unless /^password::dialog_(?<option_key>.*)/i =~ dialog_key
    add_password_value(0, option_key, dialog_value)
    true
  end

  def add_password_value(sequence, option_key, value)
    stripped_option_key = 'password::' + option_key
    prefixed_option_key = 'password::dialog_' + option_key
    add_hash_value(sequence, stripped_option_key.to_sym, value, @options_hash)
    add_hash_value(sequence, prefixed_option_key.to_sym, value, @options_hash)
  end

  def option_hash_value(dialog_key, dialog_value)
    return false unless /^dialog_option_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
    add_hash_value(sequence.to_i, option_key.to_sym, dialog_value, @options_hash)
    true
  end

  def option_array_value(dialog_key, dialog_value)
    return false unless /^array::dialog_option_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
    process_comma_separated_object_array(sequence.to_i, option_key.to_sym, dialog_value, @options_hash)
    true
  end

  def tag_hash_value(dialog_key, dialog_value)
    return false unless /^dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
    add_hash_value(sequence.to_i, option_key.to_sym, dialog_value, @tags_hash)
    true
  end

  def tag_array_value(dialog_key, dialog_value)
    return false unless /^array::dialog_tag_(?<sequence>\d*)_(?<option_key>.*)/i =~ dialog_key
    process_comma_separated_object_array(sequence.to_i, option_key.to_sym, dialog_value, @tags_hash)
    true
  end

  def generic_dialog_value(dialog_key, dialog_value)
    return false unless /^dialog_(?<option_key>.*)/i =~ dialog_key
    add_hash_value(0, option_key.to_sym, dialog_value, @options_hash)
    add_hash_value(0, dialog_key.to_sym, dialog_value, @options_hash)
    true
  end

  def set_dialog_value(key, value)
    option_value(key, value) || tag_value(key, value) || generic_value(key, value)
  end

  def option_value(key, value)
    option_hash_value(key, value) ||
      option_array_value(key, value) ||
      option_password_value(key, value)
  end

  def tag_value(key, value)
    tag_hash_value(key, value) || tag_array_value(key, value)
  end

  def generic_value(key, value)
    generic_dialog_value(key, value) || generic_password_value(key, value)
  end

  def merge_hash(hash)
    return hash unless hash.key?(0)
    hash0 = hash[0]
    mergeable_keys = hash.keys.select { |n| n.kind_of?(Integer) && n > 0 }
    # The merge is needed because quota and other methods dont have to reparse
    mergeable_keys.each { |key| hash[key] = hash0.reverse_merge(hash[key]) }
    hash
  end
end

if __FILE__ == $PROGRAM_NAME
  DialogParser.new($evm).main
end
