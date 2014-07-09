###################################
#
# EVM Automate Method: PreProvision_Clone_to_Template
#
# Notes: This default method is used to apply PreProvision customizations as follows:
# 1. VM Description/Annotations
# 2. Target VC Folder
# 3. Tag Inheritance
#
###################################
begin
  @method = 'PreProvision_Clone_to_Template'
  $evm.log("info", "#{@method} - EVM Automate Method Started")

  # Turn on verbose debugging
  @debug = true

  # Get provisioning object
  prov = $evm.root["miq_provision"]
  # $evm.log("info", "#{@method} - Inspecting Provisioning Object: #{prov.inspect}") if @debug

  # Get Provision Type
  prov_type = prov.provision_type
  $evm.log("info", "#{@method} - Provision Type: <#{prov_type}>")

  # Get template
  template = prov.vm_template
  # $evm.log("info", "#{@method} - Inspecting Template Object: #{template.inspect}") if @debug

  # Get OS Type from the template platform
  product  = template.operating_system['product_name'] rescue ''
  $evm.log("info", "#{@method} - Source Product: <#{product}>")

  ###################################
  # Set the customization spec here
  # If one selected in dialog it will be used,
  # else it will map template to customization spec based on template name
  ###################################

  # Skip automatic customization spec mapping if template is 'Other' or provision_type is clone_to_[template|vm]
  unless product.include?("Other") || prov_type.include?("clone")
    if prov.get_option(:sysprep_custom_spec).nil?
      customization_spec = prov.vm_template.name # to match the template name
      prov.set_customization_spec(customization_spec)
      $evm.log("info", "#{@method} - Provisioning object updated - <:sysprep_custom_spec> = <#{customization_spec}>")
    end
  else
    $evm.log("info", "#{@method} - Skipping automatic customization spec mapping")
  end

  ###################################
  # Set the VM Description and VM Annotations  as follows:
  # The example would allow user input in provisioning dialog "vm_description"
  # to be added to the VM notes
  ###################################
  # Stamp VM with custom description
  unless prov.get_option(:vm_description).nil?
    vmdescription = prov.get_option(:vm_description)
    prov.set_option(:vm_description, vmdescription)
    $evm.log("info", "#{@method} - Provisioning object <:vmdescription> updated with <#{vmdescription}>")
  end

  # Setup VM Annotations
  vm_notes =  "Owner: #{prov.get_option(:owner_first_name)} #{prov.get_option(:owner_last_name)}"
  vm_notes += "\nEmail: #{prov.get_option(:owner_email)}"
  vm_notes += "\nSource Template: #{prov.vm_template.name}"
  vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
  prov.set_vm_notes(vm_notes)
  $evm.log("info", "#{@method} - Provisioning object <:vm_notes> updated with <#{vm_notes}>")

  ###################################
  # Drop the VM in the targeted folder if no folder was chosen in the dialog
  # The VC folder must exist for the VM to be placed correctly else the
  # VM will placed along with the template
  # Folder starts at the Data Center level
  ###################################
  default_folder = 'DC1/Infrastructure/ManageIQ/SelfService'

  if prov.get_option(:placement_folder_name).nil?
    # prov.get_folder_paths.each do |key, path|
    # $evm.log("info", "Dumping all folders:<#{key}> - <#{path}>") if @debug
    # end
    prov.set_folder(default_folder)
    $evm.log("info", "#{@method} - Provisioning object <:placement_folder_name> updated with <#{default_folder}>")
  else
    $evm.log("info", "#{@method} - Placing VM in folder: <#{prov.get_option(:placement_folder_name)}>")
  end

  ###################################
  #
  # Inherit parent VM's tags and apply
  # them to the published template
  #
  ###################################

  # List of tag categories to carry over
  tag_categories_to_migrate = %w(environment department location function)

  # Assign variables
  prov_tags = prov.get_tags
  $evm.log("info", "#{@method} - Inspecting Provisioning Tags: <#{prov_tags.inspect}>") if @debug
  template_tags = template.tags
  $evm.log("info", "#{@method} - Inspecting Template Tags: <#{template_tags.inspect}>") if @debug

  # Loop through each source tag for matching categories
  template_tags.each do |cat_tagname|
    category, tag_value = cat_tagname.split('/')
    $evm.log("info", "#{@method} - Processing Tag Category: <#{category}> Value: <#{tag_value}>") if @debug
    next unless tag_categories_to_migrate.include?(category)
    prov.add_tag(category, tag_value)
    $evm.log("info", "#{@method} - Updating Provisioning Tags with Category: <#{category}> Value: <#{tag_value}>")
  end

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
