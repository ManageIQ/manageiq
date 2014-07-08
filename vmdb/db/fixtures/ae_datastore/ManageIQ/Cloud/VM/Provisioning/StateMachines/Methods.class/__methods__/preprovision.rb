
#
# Description: This default method is used to apply PreProvision customizations for VMware, RHEV and Amazon provisioning
#

# Process vmware specific provisioning options
def process_vmware(prov)
  # Choose the sections to process
  set_vlan = false
  set_folder = false
  set_resource_pool = false
  set_notes = true

  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  bitness = template.operating_system['bitness']
  $evm.log("info", "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}> Bitness:<#{bitness}>")

  if set_vlan
    ###################################
    # Was a VLAN selected in dialog?
    # If not you can set one here.
    ###################################
    default_vlan = "vlan1"
    default_dvs = "portgroup1"

    if prov.get_option(:vlan).nil?
      $evm.log("info", "Provisioning object <:vlan> updated with <#{default_vlan}>")
      prov.set_vlan(default_vlan)
    end
  end

  if set_folder
    ###################################
    # Drop the VM in the targeted folder if no folder was chosen in the dialog
    # The vCenter folder must exist for the VM to be placed correctly else the
    # VM will placed along with the template
    # Folder starts at the Data Center level
    ###################################
    default_folder = 'DC1/Infrastructure/ManageIQ/SelfService'

    if prov.get_option(:placement_folder_name).nil?
      prov.get_folder_paths.each { |key, path| $evm.log("info", "#{@method} - Eligible folders:<#{key}> - <#{path}>") }
      prov.set_folder(default_folder)
      $evm.log("info", "Provisioning object <:placement_folder_name> updated with <#{default_folder}>")
    else
      $evm.log("info", "Placing VM in folder: <#{prov.get_option(:placement_folder_name)}>")
    end
  end

  if set_resource_pool
    if prov.get_option(:placement_rp_name).nil?
      ############################################
      # Find and set the Resource Pool for a VM:
      ############################################
      default_resource_pool = 'MyResPool'
      respool = prov.eligible_resource_pools.detect { |c| c.name.casecmp(default_resource_pool) == 0 }
      $evm.log("info", "Provisioning object <:placement_rp_name> updated with <#{respool.name}>")
      prov.set_resource_pool(respool)
    end
  end

  if set_notes
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
    vm_notes += "\nSource Template: #{template.name}"
    vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
    prov.set_vm_notes(vm_notes)
    $evm.log("info", "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
  end
end

# Process redhat specific provisioning options
def process_redhat(prov)
  # Choose the sections to process
  set_vlan = true
  set_notes = false

  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  $evm.log("info", "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}>")

  if set_vlan
    # Set default VLAN here if one was not chosen in the dialog?
    default_vlan = "rhevm"

    if prov.get_option(:vlan).nil?
      prov.set_vlan(default_vlan)
      $evm.log("info", "Provisioning object <:vlan> updated with <#{default_vlan}>")
    end
  end

  if set_notes
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
    vm_notes += "\nSource Template: #{template.name}"
    vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
    prov.set_vm_notes(vm_notes)
    $evm.log("info", "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
  end
end

# Process Amazon specific provisioning options
def process_amazon(prov)
end # end process_amazon

# Get provisioning object
prov = $evm.root["miq_provision"]
$evm.log("info", "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

# Build case statement to determine which type of processing is required
case prov.type
when 'MiqProvisionRedhatViaIso', 'MiqProvisionRedhatViaPxe' then  process_redhat(prov)
when 'MiqProvisionVmware' then                                    process_vmware(prov)
when 'MiqProvisionAmazon' then                                    process_amazon(prov)
else                                                          $evm.log("info", "Provision Type:<#{prov.type}> does not match, skipping processing")
end
