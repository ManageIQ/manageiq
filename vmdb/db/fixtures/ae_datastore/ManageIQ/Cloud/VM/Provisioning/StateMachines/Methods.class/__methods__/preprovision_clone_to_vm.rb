#
# Description: This default method is used to apply PreProvision customizations during the cloning to a VM:
# 1. Customization Spec
# 2. VLAN
# 3. VM Description/Annotations
# 4. Target VC Folder
# 5. Resource Pool
# 6. Tag Ineritance
#

# Get provisioning object
prov = $evm.root["miq_provision"]

# Get Provision Type
prov_type = prov.provision_type
$evm.log("info", "Provision Type: <#{prov_type}>")

# Get template
template = prov.vm_template

# Get OS Type from the template platform
product  = template.operating_system['product_name'] rescue ''
$evm.log("info", "Source Product: <#{product}>")

###################################
# Set the customization spec here
# If one selected in dialog it will be used,
# else it will map the customization spec based on the
# the entry below
###################################
customization_spec = "my-custom-spec"

# Skip automatic customization spec mapping if template is 'Other'
unless product.include?("Other")
  if prov.get_option(:sysprep_custom_spec).nil?
    prov.set_customization_spec(customization_spec)
    $evm.log("info", "Provisioning object updated - <:sysprep_custom_spec> = <#{customization_spec}>")
  end
else
  $evm.log("info", "Skipping automatic customization spec mapping")
end

###################################
# Was a VLAN selected in dialog?
# If not you can set one here.
###################################
default_vlan = "vlan1"

if prov.get_option(:vlan).nil?
  prov.set_vlan(default_vlan)
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
  $evm.log("info", "Provisioning object <:vmdescription> updated with <#{vmdescription}>")
end

# Setup VM Annotations
vm_notes =  "Owner: #{prov.get_option(:owner_first_name)} #{prov.get_option(:owner_last_name)}"
vm_notes += "\nEmail: #{prov.get_option(:owner_email)}"
vm_notes += "\nSource VM: #{prov.vm_template.name}"
vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
prov.set_vm_notes(vm_notes)
$evm.log("info", "Provisioning object <:vm_notes> updated with <#{vm_notes}>")

###################################
# Drop the VM in the targeted folder if no folder was chosen in the dialog
# The VC folder must exist for the VM to be placed correctly else the
# VM will placed along with the template
# Folder starts at the Data Center level
###################################
default_folder = 'DC1/Infrastructure/ManageIQ/SelfService'

if prov.get_option(:placement_folder_name).nil?
  prov.set_folder(default_folder)
  $evm.log("info", "Provisioning object <:placement_folder_name> updated with <#{default_folder}>")
else
  $evm.log("info", "Placing VM in folder: <#{prov.get_option(:placement_folder_name)}>")
end

###################################
#
# Inherit parent VM's tags and apply
# them to the cloned VM
#
###################################

# List of tag categories to carry over
tag_categories_to_migrate = %w(environment department location function)

# Assign variables
prov_tags = prov.get_tags
$evm.log("info", "Provisioning Tags: <#{prov_tags.inspect}>")
template_tags = template.tags
$evm.log("info", "Template Tags: <#{template_tags.inspect}>")

# Loop through each source tag for matching categories
template_tags.each do |cat_tagname|
  category, tag_value = cat_tagname.split('/')
  $evm.log("info", "Processing Tag Category: <#{category}> Value: <#{tag_value}>")
  next unless tag_categories_to_migrate.include?(category)
  prov.add_tag(category, tag_value)
  $evm.log("info", "Updating Provisioning Tags with Category: <#{category}> Value: <#{tag_value}>")
end
