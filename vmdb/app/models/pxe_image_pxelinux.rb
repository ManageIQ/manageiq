class PxeImagePxelinux < PxeImage
  def build_pxe_contents(ks_access_path, ks_device)
    options = super
    options.insert(0, "initrd=#{self.initrd} ") unless self.initrd.blank?

    pxe = <<-PXE
timeout 0
default #{self.name}

label #{self.name}
   menu label #{self.description}
PXE

    pxe << "   kernel #{self.kernel}\n" unless self.kernel.nil?
    pxe << "   append #{options}\n"     unless options.blank?
    pxe << "\n"
  end

  def self.pxe_server_filename(mac_address)
    "01-#{mac_address.gsub(/:/, "-").downcase.strip}"
  end

  def self.parse_contents(contents, label = nil)
    self.corresponding_menu.parse_contents(contents)
  end
end
