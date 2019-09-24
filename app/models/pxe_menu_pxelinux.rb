class PxeMenuPxelinux < PxeMenu
  has_many :pxe_images,
           :class_name  => "PxeImagePxelinux",
           :foreign_key => :pxe_menu_id,
           :dependent   => :destroy,
           :inverse_of  => :pxe_menu

  def self.parse_contents(contents)
    items = []
    current_item = nil

    contents.each_line do |line|
      line = line.strip
      next if line.blank?

      key = line.split.first.downcase.to_sym
      value = line[key.to_s.length..-1].strip

      next if key != :label && current_item.nil?

      case key
      when :label
        current_item = {:label => value}
        items << current_item
      when :menu
        sub_key = value.split.first
        value = value[sub_key.length..-1].strip

        key = [key, sub_key].join("_").to_sym
        value = true if key == :menu_default

        current_item[key] = value if [:menu_label, :menu_default].include?(key)
      when :append
        current_item[:kernel_options], current_item[:initrd] = parse_append(value)
      else
        current_item[key] = value if [:kernel].include?(key)
      end
    end

    bad, good = items.partition { |i| i[:kernel].blank? }
    bad.each { |i| _log.warn("Image #{i[:label]} missing kernel - Skipping") }
    good
  end

  def self.parse_append(append)
    options = append.split(' ')

    initrd   = options.detect { |o| o.starts_with?("initrd=") }
    initrd &&= initrd[7..-1]

    rejects = %w( initrd= )
    options.reject! { |o| o.blank? || rejects.any? { |r| o.starts_with?(r) } }
    return options.join(' '), initrd
  end

  def self.display_name(number = 1)
    n_('PXE Menu (pxelinux)', 'PXE Menus (pxelinux)', number)
  end
end
