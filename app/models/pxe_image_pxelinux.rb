class PxeImagePxelinux < PxeImage
  def build_pxe_contents(kernel_args)
    options = super
    options.insert(0, "initrd=#{initrd} ") if initrd.present?

    pxe = <<~PXE
      timeout 0
      default #{name}

      label #{name}
         menu label #{description}
    PXE

    pxe << "   kernel #{kernel}\n" unless kernel.nil?
    pxe << "   append #{options}\n"     if options.present?
    pxe << "\n"
  end

  def self.pxe_server_filename(mac_address)
    "01-#{mac_address.tr(":", "-").downcase.strip}"
  end

  def self.parse_contents(contents, _label = nil)
    corresponding_menu.parse_contents(contents)
  end
end
