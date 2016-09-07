#
# Description: This method Performs the following functions:
# 1. YAML load the Service Dialog Options from @task.get_option(:parsed_dialog_options))
# 2. Set the name of the service
# 3. Set tags on the service
# 5. Pass down any dialog options and tags to child catalog items pointing to CatalogItemInitialization
# Important - The dialog_parser automate method has to run prior to this in order to populate the dialog information.
#
def log_and_update_message(level, msg, update_message = false)
  $evm.log(level, msg.to_s)
  @task.message = msg if @task && (update_message || level == 'error')
end

# Loop through all tags from the dialog and create the categories and tags automatically
def create_tags(category, single_value, tag)
  log_and_update_message(:info, "Processing create_tags...", true)
  # Convert to lower case and replace all non-word characters with underscores
  category_name = category.to_s.downcase.gsub(/\W/, '_')
  tag_name = tag.to_s.downcase.gsub(/\W/, '_')

  # if the category exists else create it
  unless $evm.execute('category_exists?', category_name)
    log_and_update_message(:info, "Category #{category_name} doesn't exist, creating category")
    $evm.execute('category_create', :name         => category_name,
                                    :single_value => single_value,
                                    :description  => category.to_s)
  end
  # if the tag exists else create it
  unless $evm.execute('tag_exists?', category_name, tag_name)
    log_and_update_message(:info, "Adding new tag #{tag_name} in Category #{category_name}")
    $evm.execute('tag_create', category_name, :name => tag_name, :description => tag.to_s)
  end
  log_and_update_message(:info, "Processing create_tags...Complete", true)
end

def override_service_attribute(dialogs_options_hash, attr_name)
  service_attr_name = "service_#{attr_name}".to_sym

  log_and_update_message(:info, "Processing override_attribute for #{service_attr_name}...", true)
  attr_value = dialogs_options_hash.fetch(service_attr_name, nil)
  attr_value = "#{@service.name}-#{Time.now.strftime('%Y%m%d-%H%M%S')}" if attr_name == 'name' && attr_value.nil?

  log_and_update_message(:info, "Setting service attribute: #{attr_name} to: #{attr_value}")
  @service.send("#{attr_name}=", attr_value)

  log_and_update_message(:info, "Processing override_attribute for #{service_attr_name}...Complete", true)
end

def process_tag(tag_category, tag_value)
  return if tag_value.blank?
  create_tags(tag_category, true, tag_value)
  $evm.log(:info, "Assigning Tag: {#{tag_category} => tag: #{tag_value}} to Service: #{@service.name}")
  @service.tag_assign("#{tag_category}/#{tag_value}")
end

# service_tagging - tag the service with tags in dialogs_tags_hash[0]
def tag_service(dialogs_tags_hash)
  log_and_update_message(:info, "Processing tag_service...", true)

  # Look for tags with a sequence_id of 0 to tag the service
  dialogs_tags_hash.fetch(0, {}).each do |key, value|
    log_and_update_message(:info, "Processing tag: #{key.inspect} value: #{value.inspect}")
    tag_category = key.downcase
    Array.wrap(value).each do |tag_entry|
      process_tag(tag_category, tag_entry.downcase)
    end
  end
  log_and_update_message(:info, "Processing tag_service...Complete", true)
end

def yaml_data(option)
  @task.get_option(option).nil? ? nil : YAML.load(@task.get_option(option))
end

def parsed_dialog_information
  dialog_options_hash = yaml_data(:parsed_dialog_options)
  dialog_tags_hash = yaml_data(:parsed_dialog_tags)
  if dialog_options_hash.blank? && dialog_tags_hash.blank?
    log_and_update_message(:info, "Instantiating dialog_parser to populate dialog options")
    $evm.instantiate('/Service/Provisioning/StateMachines/Methods/DialogParser')
    dialog_options_hash = yaml_data(:parsed_dialog_options)
    dialog_tags_hash = yaml_data(:parsed_dialog_tags)
  end

  log_and_update_message(:info, "dialog_options: #{dialog_options_hash.inspect}")
  log_and_update_message(:info, "tag_options: #{dialog_tags_hash.inspect}")
  return dialog_options_hash, dialog_tags_hash
end

begin
  @task = $evm.root['service_template_provision_task']

  @service = @task.destination
  log_and_update_message(:info, "Service: #{@service.name} id: #{@service.id} tasks: #{@task.miq_request_tasks.count}")

  dialog_options_hash, dialog_tags_hash = parsed_dialog_information

  unless dialog_options_hash.blank?
    override_service_attribute(dialog_options_hash.fetch(0, {}), "name")
    override_service_attribute(dialog_options_hash.fetch(0, {}), "description")
  end

  tag_service(dialog_tags_hash) unless dialog_tags_hash.blank?

rescue => err
  log_and_update_message(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  @task.finished(err.to_s) if @task
  exit MIQ_ABORT
end
