class PxeMenu < ActiveRecord::Base
  belongs_to :pxe_server

  def self.class_from_contents(contents)
    line = contents.to_s.each_line { |l| break l }
    return PxeMenuIpxe if line =~ /^#!\s*ipxe\s*$/
    PxeMenuPxelinux
  end

  def self.model_suffix
    self.name[7..-1]
  end

  def self.corresponding_image
    @corresponding_image ||= "PxeImage#{self.model_suffix}".constantize
  end

  def synchronize
    synchronize_contents

    klass = self.class.class_from_contents(contents)
    if klass != self.class
      self.save!

      # If sublass changes type to a different subclass
      self.pxe_images.destroy_all if self.class != PxeMenu

      self.update_attribute(:type, klass.name)
      target = klass.find(self.id)
    else
      target = self
    end

    target.synchronize_images
    target.save!
  end

  def synchronize_contents
    self.contents = self.pxe_server.read_file(self.file_name)
  end

  def synchronize_images
    log_header = "MIQ(#{self.class.name}#synchronize_images)"

    $log.info("#{log_header} Synchronizing Menu Items in Menu [#{self.file_name}] on PXE Server [#{self.pxe_server.name}]")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = self.pxe_images.index_by(&:name)

    items = self.class.parse_contents(self.contents)

    # Deal with multiple images with the same label in a file
    incoming = items.group_by { |h| h[:label] }
    incoming.each_key do |name|
      array = incoming[name]
      $log.warn("#{log_header} duplicate name <#{name}> in menu <#{self.file_name}> on PXE Server <#{self.pxe_server.name}>") if array.length > 1
      incoming[name] = array.first
    end

    incoming.each do |name, ihash|
      image                 = current.delete(name) || self.pxe_images.build
      image.pxe_server      = self.pxe_server
      image.path            = self.file_name
      image.parsed_contents = ihash
      image.save!

      stats_key = image.new_record? ? :adds : :updates
      stats[stats_key] += 1
    end

    stats[:deletes] = current.length
    self.pxe_images.delete(current.values)

    $log.info("#{log_header} Synchronizing Menu Items in Menu [#{self.file_name}] on PXE Server [#{self.pxe_server.name}]... Complete - #{stats.inspect}")
  end
end
