###################################
#
# EVM Automate Method: CatalogItemInitialization
#
# Notes: This method Performs the following functions:
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
###################################
begin
  @method = 'CatalogItemInitialization'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn of verbose logging
  @debug = true

  #########################
  #
  # Method: get_tags_hash
  # Description: Look for service dialog variables in the dialog options hash that start with "tag_[0-9]",
  #
  ##########################
  def get_tags_hash(dialog_options)
    # Setup regular expression for service dialog tags
    tags_regex = /^dialog_tag_\d*_(.*)/

    tags_hash = {}

    # Loop through all of the tags and build an options_hash from them
    dialog_options.each do |k, v|
      if tags_regex =~ k
        # $evm.log("info", "#{@method} - Processing Tag Key:<#{k.inspect}> Value:<#{v.inspect}>") if @debug
        # Convert key to symbol
        tag_category = Regexp.last_match[1].to_sym
        tag_value = v.downcase

        unless tag_value.blank?
          $evm.log("info", "#{@method} - Adding category:<#{tag_category.inspect}> tag:<#{tag_value.inspect}> to tags_hash") if @debug
          tags_hash[tag_category] = tag_value
        end
      end
    end
    $evm.log("info", "#{@method} - Inspecting tags_hash:<#{tags_hash.inspect}>") if @debug
    tags_hash
  end

  #########################
  #
  # Method: get_options_hash
  # Description: Look for service dialog variables in the dialog options hash that start with "option_[0-9]",
  #
  ##########################
  def get_options_hash(dialog_options)
    # Setup regular expression for service dialog tags
    options_regex = /^dialog_option_\d*_(.*)/
    options_hash = {}

    # Loop through all of the options and build an options_hash from them
    dialog_options.each do |k, v|
      if options_regex =~ k
        option_key = Regexp.last_match[1].to_sym
        option_value = v

        unless option_value.blank?
          $evm.log("info", "#{@method} - Adding option_key:<#{option_key.inspect}> option_value:<#{option_value.inspect}> to options_hash") if @debug
          options_hash[option_key] = option_value
        end
      else
        unless v.nil?
          $evm.log("info", "#{@method} - Adding option:<#{k.to_sym.inspect}> value:<#{v.inspect}> to options_hash") if @debug
          options_hash[k.to_sym] = v
        end
      end
    end
    $evm.log("info", "#{@method} - Inspecting options_hash:<#{options_hash.inspect}>") if @debug
    options_hash
  end

  #########################
  #
  # Method: tag_service
  # Description: Look in tags_hash for tags and tag the service
  #
  ##########################
  def tag_service(service, tags_hash)
    # Look for tags with a sequence_id of 0 to tag the destination Service
    unless tags_hash.nil?
      tags_hash.each do |k, v|
        $evm.log("info", "#{@method} - Adding Tag:<#{k.inspect}/#{v.inspect}> to Service:<#{service.name}>") if @debug
        service.tag_assign("#{k}/#{v}")
      end
    end
  end

  # Get the task object from root
  service_template_provision_task = $evm.root['service_template_provision_task']

  # List Service Task Attributes
  # service_template_provision_task.attributes.sort.each { |k, v| $evm.log("info", "#{@method} - Task:<#{service_template_provision_task}> Attributes - #{k}: #{v}")} if @debug

  # Get destination service object
  service = service_template_provision_task.destination
  $evm.log("info", "#{@method} - Detected Service:<#{service.name}> Id:<#{service.id}>") if @debug

  # Get dialog options from options hash
  # {:dialog=>{"option_0_myvar"=>"myprefix", "option_1_vservice_workers"=>"2", "tag_0_environment"=>"test", "tag_0_location"=>"paris",
  # "option_2_vm_memory"=>"2048", "option_0_vlan"=>"Internal", "option_1_cores_per_socket"=>"1"}}
  dialog_options = service_template_provision_task.dialog_options
  $evm.log("info", "#{@method} - Inspecting Dialog Options:<#{dialog_options.inspect}>") if @debug

  # Get tags_hash
  tags_hash = get_tags_hash(dialog_options)

  # Tag Service
  tag_service(service, tags_hash)

  # Get options_hash
  options_hash = get_options_hash(dialog_options)

  # Process Child Tasks
  service_template_provision_task.miq_request_tasks.each do |t|
    # Child Service
    child_service = t.destination

    # Process grandchildren service options
    unless t.miq_request_tasks.nil?
      grandchild_tasks = t.miq_request_tasks
      # $evm.log("info","#{@method} - Inspecting Grandchild Tasks:<#{grandchild_tasks.inspect}>") if @debug

      grandchild_tasks.each do |gc|
        $evm.log("info", "#{@method} -  Detected Grandchild Task ID:<#{gc.id}> Description:<#{gc.description}> source type:<#{gc.source_type}>") if @debug

        # If child task is provisioning then apply tags and options
        if gc.source_type == "template"
          unless tags_hash.nil?
            tags_hash.each do |k, v|
              $evm.log("info", "#{@method} - Adding Tag:<#{k.inspect}/#{v.inspect}> to Provisioning ID:<#{gc.id}>") if @debug
              gc.add_tag(k, v)
            end
          end
          unless options_hash.nil?
            options_hash.each do |k, v|
              $evm.log("info", "#{@method} - Adding Option:<{#{k.inspect} => #{v.inspect}}> to Provisioning ID:<#{gc.id}>") if @debug
              gc.set_option(k, v)
            end
          end
        else
          $evm.log("info", "#{@method} - Invalid Source Type:<#{gc.source_type}>. Skipping task ID:<#{gc.id}>") if @debug
        end # if gc.source_type
      end # grandchild_tasks.each do
    end # unless t.miq_request_tasks.nil?
  end # service_template_provision_task.miq_request_tasks.each do

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
