module MiqProvision::Pxe
  def pxe_and_windows_image
    return @pxe_image, @windows_image unless @pxe_image.nil?

    image_id = get_option(:pxe_image_id)
    if image_id.kind_of?(String)
      # "new" style of choosing either a pxe image or a windows image, and
      #   storing the pxe_image_id field as "ClassName::id"
      klass, id = image_id.split("::")
      image = klass.constantize.find_by(:id => id)

      if image.kind_of?(WindowsImage)
        @pxe_image     = pxe_server.default_pxe_image_for_windows
        @windows_image = image
      else
        @pxe_image     = image
        @windows_image = nil
      end
    else
      # "old" style of choosing both the pxe image and windows image manually
      @pxe_image     = PxeImage.find_by(:id => get_option(:pxe_image_id))
      @windows_image = WindowsImage.find_by(:id => get_option(:windows_image_id))
    end

    return @pxe_image, @windows_image
  end

  def pxe_server
    @pxe_server ||= PxeServer.find_by(:id => get_option(:pxe_server_id))
  end

  def customization_template
    @customization_template ||= CustomizationTemplate.find_by(:id => get_option(:customization_template_id))
  end

  # From http://stackoverflow.com/questions/1825928/netmask-to-cidr-in-ruby
  def cidr
    subnet_mask = get_option(:subnet_mask)
    require 'ipaddr'
    Integer(32 - Math.log2((IPAddr.new(subnet_mask.to_s, Socket::AF_INET).to_i ^ 0xffffffff) + 1))
  rescue ArgumentError => err
    _log.warn("Cannot convert subnet #{subnet_mask.inspect} to CIDR because #{err.message}")
    return nil
  end

  def prepare_customization_template_substitution_options(mac_address = nil)
    substitution_options = nil
    if customization_template
      substitution_options = options.dup
      substitution_options[:miq_provision_id]             = id
      substitution_options[:post_install_callback_url] = post_install_callback_url
      substitution_options[:cidr]                         = cidr
      substitution_options[:mac_address]                  = mac_address if mac_address
    end
    substitution_options
  end

  def create_pxe_files
    pxe_image, windows_image = pxe_and_windows_image

    mac_address = get_mac_address_of_nic_on_requested_vlan
    raise _("MAC Address is nil") if mac_address.nil?

    substitution_options = prepare_customization_template_substitution_options(mac_address)
    pxe_server.create_provisioning_files(pxe_image, mac_address, windows_image, customization_template, substitution_options)
  end

  def delete_pxe_files
    pxe_image, windows_image = pxe_and_windows_image

    mac_address = get_mac_address_of_nic_on_requested_vlan
    raise _("MAC Address is nil") if mac_address.nil?

    pxe_server.delete_provisioning_files(pxe_image, mac_address, windows_image, customization_template)
  end
end
