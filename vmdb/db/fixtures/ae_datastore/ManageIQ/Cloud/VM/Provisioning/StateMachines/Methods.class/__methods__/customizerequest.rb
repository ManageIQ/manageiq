#
# Description: This method is used to Customize the Provisioning Request
#
# 1. Customization Specification Mapping for VMware provisioning
# 2. Customization Template and PXE for RHEV provisioning
# 3. Customization Processing for Amazon provisioning
# 4. Customization Template Processing for RHEV based ISO Provisioning
#

# This method sets the customization spec for vmware
def set_customspec(prov, spec)
  prov.set_customization_spec(spec, true)
  $evm.log("info", "Provisioning object updated - <:sysprep_custom_spec> with <#{prov.get_option(:sysprep_custom_spec)}>")
  $evm.log("info", "Provisioning object <:sysprep_spec_override> updated with <#{prov.get_option(:sysprep_spec_override)}>")
end

def process_vmware(mapping, prov)
  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  bitness = template.operating_system['bitness']
  $evm.log("info", "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}> Bitness:<#{bitness}>")

  # Skip automatic customization spec mapping if template is 'Other' or provision_type is clone_to_[template]
  unless product.include?("Other") || prov.provision_type.include?("clone_to_template")
    case mapping

    when 0
      # Skip mapping
      $evm.log("info", "Skipping #{prov.type} mapping:<#{mapping}>")

    when 1
      # Automatic customization specification mapping if template is RHEL,Suse or Windows
      if product.include?("red hat") || product.include?("suse") || product.include?("windows")
        spec = prov.vm_template.name # to match the template name
        set_customspec(prov, spec)
      end

    when 2
      ###################################
      # Use this option to use a combination of product name and bitness to select your customization specification
      ###################################
      spec = "default_spec" # unknown type

      if product.include?("2003")
        # Windows Server 2003
        if product.include?("enterprise")
          spec = "W2K3R2-Entx64"
        else
          if bitness == 64 # 2003 Std x64
            spec = "W2K3R2-Stdx64" # Win2003 64 bit
          else # 2003 Std x86
            spec = "W2K3R2-Stdx32" # Win2003 32 bit
          end
        end
      elsif product.include?("2008")
        # Windows Server 2008
        if product.include?("datacenter")
          spec = "W2K8R2-Datx64" # Win2k8 64 bit
        else # Standard x64
          spec = "W2K8R2-Stdx64" # Win2k8 32 bit
        end
      elsif product.include?("windows 7")
        if bitness == 64
          spec = "W7-Prox64" # Windows7 64 bit
        else
          spec = "W7-Prox86" # Windows7 32 bit
        end
      elsif product.include?("windows xp")
        if product.include?("64-bit")
          spec = "WXP-Prox64" # Windows XP 64 bit
        else
          spec = "WXP-Prox32" # Windows XP 32 bit
        end
      elsif product.include?("suse")
        spec = "suse_custom_spec" # Suse
      elsif product.include?("red hat")
        spec = "rhel_custom_spec" # RHEL
      end
      $evm.log("info", "VMware Custom Specification:<#{spec}> bitness:<#{bitness}>")

      # Set values in provisioning object
      set_customspec(prov, spec) unless spec.nil?
    when 3
      #
      # Enter your own VMware custom mapping here
      #
    else
      # Skip mapping
      $evm.log("info", "Skipping #{prov.type} mapping:<#{mapping}>")
    end # end case
  end # end unless
end # end process_vmware

# Red Hat PXE Provisioning
def process_redhat(mapping, prov)
  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  $evm.log("info", "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}>")

  case mapping

  when 0
    # No mapping

  when 1
    if product.include?("windows")
      # find the windows image that matches the template name if a PXE Image was NOT chosen in the dialog
      if prov.get_option(:pxe_image_id).nil?

        pxe_image = prov.eligible_windows_images.detect { |pi| pi.name.casecmp(template.name) == 0 }
        if pxe_image.nil?
          message "Failed to find matching PXE Image"
          prov.message = message
          $evm.log("info", "Inspecting Eligible Windows Images:<#{prov.eligible_windows_images.inspect}>")
          raise message
        else
          $evm.log("info", "Found matching Windows PXE Image ID:<#{pxe_image.id}> Name:<#{pxe_image.name}> Description:<#{pxe_image.description}>")
        end
        prov.set_windows_image(pxe_image)
        $evm.log("info", "Provisioning object <:pxe_image_id> updated with <#{prov.get_option(:pxe_image_id).inspect}>")
      end
      # Find the first customization template that matches the template name if none was chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        cust_temp = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name) == 0 }
        if cust_temp.nil?
          message "Failed to find matching PXE Image"
          prov.message = message
          $evm.log("info", "Inspecting Eligible Customization Templates:<#{prov.eligible_customization_templates.inspect}>")
          raise message
        end
        $evm.log("info", "Found mathcing Windows Customization Template ID:<#{cust_temp.id}> Name:<#{cust_temp.name}> Description:<#{cust_temp.description}>")
        prov.set_customization_template(cust_temp)
        $evm.log("info", "Provisioning object <:customization_template_id> updated with <#{prov.get_option(:customization_template_id).inspect}>")
      end
    else
      # find the first PXE Image that matches the template name if NOT chosen in the dialog
      if prov.get_option(:pxe_image_id).nil?
        pxe_image = prov.eligible_pxe_images.detect { |pi| pi.name.casecmp(template.name) == 0 }
        $evm.log("info", "Found Linux PXE Image ID:<#{pxe_image.id}> Name:<#{pxe_image.name}> Description:<#{pxe_image.description}>")
        prov.set_pxe_image(pxe_image)
        $evm.log("info", "Provisioning object <:pxe_image_id> updated with <#{prov.get_option(:pxe_image_id).inspect}>")
      end
      # Find the first Customization Template that matches the template name if NOT chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        cust_temp = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name) == 0 }
        $evm.log("info", "Found Customization Template ID:<#{cust_temp.id}> Name:<#{cust_temp.name}> Description:<#{cust_temp.description}>")
        prov.set_customization_template(cust_temp)
        $evm.log("info", "Provisioning object <:customization_template_id> updated with <#{prov.get_option(:customization_template_id).inspect}>")
      end
    end
  when 3
    #
    # Enter your own RHEV PXE custom mapping here
    #

  else
    # Skip mapping
    $evm.log("info", "Skipping #{prov.type} mapping:<#{mapping}>")
  end # end case
end # end process_redhat

# Red Hat ISO Provisioning
def process_redhat_iso(mapping, prov)
  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  $evm.log("info", "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}>")

  case mapping

  when 0
    # No mapping
  when 1
    if product.include?("windows")
      # Linux Support only for now

    else
      # Linux - Find the first ISO Image that matches the template name if NOT chosen in the dialog
      if prov.get_option(:iso_image_id).nil?
        iso_image = prov.eligible_iso_images.detect { |iso| iso.name.casecmp(template.name) == 0 }
        $evm.log("info", "Found Linux ISO Image ID:<#{iso_image.id}> Name:<#{iso_image.name}> Description:<#{iso_image.description}>")
        prov.set_iso_image(iso_image)
        $evm.log("info", "Provisioning object <:iso_image_id> updated with <#{prov.get_option(:iso_image_id).inspect}>")
      end
      # Find the first Customization Template that matches the template name if NOT chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        cust_temp = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name) == 0 }
        $evm.log("info", "Found Customization Template ID:<#{cust_temp.id}> Name:<#{cust_temp.name}> Description:<#{cust_temp.description}>")
        prov.set_customization_template(cust_temp)
        $evm.log("info", "Provisioning object <:customization_template_id> updated with <#{prov.get_option(:customization_template_id).inspect}>")
      end
    end
  when 2
    #
    # Enter your own RHEV ISO custom mapping here
    #

  else
    # Skip mapping
    $evm.log("info", "Skipping #{prov.type} mapping:<#{mapping}>")
  end
end

def process_amazon(mapping, prov)
end # end process_amazon

# Get provisioning object
prov = $evm.root["miq_provision"]

$evm.log("info", "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

# Build case statement to determine which type of processing is required
case prov.type

when 'MiqProvisionRedhatViaIso'
  ##########################################################
  # Red Hat Customization Template Mapping for ISO Provisioning
  #
  # Possible values:
  #   0 - (DEFAULT No Mapping) This option skips the mapping of iso images and customization templates
  #
  #   1 - CFME will look for a iso image and a customization template with
  #   the exact name as the template name if none were chosen from the provisioning dialog
  #
  #   2 - Include your own custom mapping logic here
  #
  ##########################################################
  mapping = 0
  process_redhat_iso(mapping, prov)

when 'MiqProvisionRedhatViaPxe'
  ##########################################################
  # Red Hat Customization Template Mapping for PXE Provisioning
  #
  # Possible values:
  #   0 - (DEFAULT No Mapping) This option skips the mapping of pxe images and customization templates
  #
  #   1 - CFME will look for a pxe image and a customization template with
  #   the exact name as the template name if none were chosen from the provisioning dialog
  #
  #   2 - Include your own custom mapping logic here
  #
  ##########################################################
  mapping = 0
  process_redhat_iso(mapping, prov)

when 'MiqProvisionVmware'
  ##########################################################
  # VMware Customization Specification Mapping
  #
  # Possible values:
  #   0 - (Default No Mapping) This option is automatically chosen if it finds a customization
  #   specification mapping chosen from the dialog
  #
  #   1 - CFME will look for a customization specification with
  #   the exact name as the template name
  #
  #   2 - Use this option to use a combination of product name and bitness to
  #   select your customization specification
  #
  #   3 - Include your own custom mapping logic here
  ##########################################################
  mapping = 0
  process_vmware(mapping, prov)

when 'MiqProvisionAmazon'
  ##########################################################
  # Amazon Specification Mapping
  #
  # Placeholder for future enhancements:
  #
  ##########################################################
  mapping = 0
  process_amazon(mapping, prov)

else
  $evm.log("info", "Provisioning Type:<#{prov.type}> does not match, skipping processing")
end

