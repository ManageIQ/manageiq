class PxeMenuIpxe < PxeMenu
  has_many :pxe_images,
           :class_name  => "PxeImageIpxe",
           :foreign_key => :pxe_menu_id,
           :dependent   => :destroy,
           :inverse_of  => :pxe_menu

  def self.parse_contents(contents)
    menu_items = parse_menu(contents)
    entries = parse_labels(contents, menu_items.keys)
    entries.each { |e| e[:menu_label] = menu_items[e[:label]] }
    entries
  end

  def self.parse_labels(contents, labels)
    items = []
    current_item = nil

    contents.each_line do |line|
      line = line.strip
      next if line.blank? || line[0, 1] == '#'
      next if line[0, 1] != ':' && current_item.nil?

      if line[0, 1] == ':'
        key   = :label
        value = line[1..-1].strip
      else
        key   = line.split.first.downcase.to_sym
        value = line[key.to_s.length..-1].strip
      end

      next if key != :label && current_item.nil?

      case key
      when :label
        next unless labels.include?(value)
        current_item = {:label => value}
      when :kernel
        current_item[:kernel], current_item[:kernel_options] = parse_kernel(value)
      when :boot, :chain, :reboot
        items << current_item
        current_item = nil
      else
        current_item[key] = value if [:initrd].include?(key)
      end
    end
    items << current_item

    bad, good = items.compact.partition { |i| i[:kernel].blank? }
    bad.each { |i| _log.warn("Image #{i[:label]} missing kernel - Skipping") }
    good
  end

  def self.parse_kernel(kernel)
    options = kernel.split(' ')
    kernel  = options.shift

    return kernel, options.join(' ')
  end

  def self.parse_menu(contents)
    items = {}
    contents.each_line do |line|
      line = line.strip
      sp = line.split(' ')
      next unless sp[0] == 'item'

      items[sp[1]] = sp[2..-1].join(' ')
    end
    items
  end

  def self.display_name(number = 1)
    n_('PXE Menu (iPXE)', 'PXE Menus (iPXE)', number)
  end
end
