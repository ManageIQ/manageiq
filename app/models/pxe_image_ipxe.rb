class PxeImageIpxe < PxeImage
  def build_pxe_contents(kernel_args)
    pxe = "#!ipxe\n"
    pxe << "kernel #{kernel} #{super}\n"
    pxe << "initrd #{initrd}\n" if initrd.present?
    pxe << "boot\n"
  end

  def self.pxe_server_filename(mac_address)
    mac_address.gsub(/:/, "-").downcase.strip
  end

  def self.parse_contents(contents, label)
    current_item = {:label => label}
    contents.each_line do |line|
      line  = line.strip
      key   = line.split.first.downcase.to_sym
      value = line[key.to_s.length..-1].strip

      case key
      when :kernel
        current_item[:kernel], current_item[:kernel_options] = corresponding_menu.parse_kernel(value)
      else
        current_item[key] = value if [:initrd].include?(key)
      end
    end

    if current_item[:kernel].blank?
      _log.warn("Image #{current_item[:label]} missing kernel - Skipping")
      return []
    end

    [current_item]
  end
end
