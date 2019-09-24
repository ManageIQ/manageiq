class PxeMenu < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :pxe_server
  has_many :pxe_images, :dependent => :destroy

  def self.class_from_contents(contents)
    line = contents.to_s.each_line { |l| break l }
    return PxeMenuIpxe if line =~ /^#!\s*ipxe\s*$/
    PxeMenuPxelinux
  end

  def self.model_suffix
    name[7..-1]
  end

  def self.corresponding_image
    @corresponding_image ||= "PxeImage#{model_suffix}".constantize
  end

  def synchronize
    synchronize_contents

    klass = self.class.class_from_contents(contents)
    if klass != self.class
      self.save!

      # If sublass changes type to a different subclass
      pxe_images.destroy_all if self.class != PxeMenu

      update_attribute(:type, klass.name)
      target = klass.find(id)
    else
      target = self
    end

    target.synchronize_images
    target.save!
  end

  def synchronize_contents
    self.contents = pxe_server.read_file(file_name)
  end

  def synchronize_images
    _log.info("Synchronizing Menu Items in Menu [#{file_name}] on PXE Server [#{pxe_server.name}]")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = pxe_images.index_by(&:name)

    items = self.class.parse_contents(contents)

    # Deal with multiple images with the same label in a file
    incoming = items.group_by { |h| h[:label] }
    incoming.each_key do |name|
      array = incoming[name]
      _log.warn("duplicate name <#{name}> in menu <#{file_name}> on PXE Server <#{pxe_server.name}>") if array.length > 1
      incoming[name] = array.first
    end

    incoming.each do |name, ihash|
      image                 = current.delete(name) || pxe_images.build
      image.pxe_server      = pxe_server
      image.path            = file_name
      image.parsed_contents = ihash
      image.save!

      stats_key = image.new_record? ? :adds : :updates
      stats[stats_key] += 1
    end

    stats[:deletes] = current.length
    pxe_images.delete(current.values)

    _log.info("Synchronizing Menu Items in Menu [#{file_name}] on PXE Server [#{pxe_server.name}]... Complete - #{stats.inspect}")
  end

  def self.display_name(number = 1)
    n_('PXE Menu', 'PXE Menus', number)
  end
end
