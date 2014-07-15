class PxeServer < ActiveRecord::Base
  autoload :WimParser, File.join(File.dirname(__FILE__), %w{.. .. .. lib util win32 wim_parser})

  include FileDepotMixin
  include ReportableMixin

  alias_attribute :description, :name

  default_value_for :customization_directory, ""

  serialize :visibility

  validates_presence_of   :name, :uri
  validates_uniqueness_of :name

  has_many :pxe_menus,      :dependent => :destroy
  has_many :pxe_images,     :dependent => :destroy
  has_many :advertised_pxe_images, :class_name => "PxeImage", :conditions => "pxe_menu_id IS NOT NULL"
  has_many :discovered_pxe_images, :class_name => "PxeImage", :conditions => {:pxe_menu_id => nil}
  has_many :windows_images, :dependent => :destroy

  def images
    self.pxe_images + self.windows_images
  end

  def advertised_images
    self.advertised_pxe_images + self.windows_images
  end

  def discovered_images
    self.discovered_pxe_images + self.windows_images
  end

  def default_pxe_image_for_windows=(image)
    image.update_attributes(:default_for_windows => true)
    clear_association_cache
  end

  def default_pxe_image_for_windows
    self.pxe_images.where(:default_for_windows => true).first
  end

  def synchronize_advertised_images
    self.pxe_menus.each { |m| m.synchronize }
    sync_windows_images
    clear_association_cache
    self.update_attribute(:last_refresh_on, Time.now.utc)
  end

  def synchronize_advertised_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "synchronize_advertised_images"
    )
  end

  def sync_images
    sync_pxe_images
    sync_windows_images
    clear_association_cache
    self.update_attribute(:last_refresh_on, Time.now.utc)
  end

  def sync_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "sync_images"
    )
  end

  def sync_pxe_images
    log_header = "MIQ(#{self.class.name}#sync_pxe_images)"
    $log.info("#{log_header} Synchronizing PXE images on PXE Server [#{self.name}]...")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = self.pxe_images.where(:pxe_menu_id => nil).index_by { |i| [i.path, i.name] }

    with_depot do
      begin
        self.file_glob("#{self.pxe_directory}/*").each do |f|
          next unless self.file_file?(f)

          relative_path = Pathname.new(f).relative_path_from(Pathname.new(self.pxe_directory)).to_s

          contents    = self.file_read(f)
          menu_class  = PxeMenu.class_from_contents(contents)
          image_class = menu_class.corresponding_image
          image_list  = image_class.parse_contents(contents, File.basename(f))

          # Deal with multiple images with the same label in a file
          incoming = image_list.group_by { |h| h[:label] }
          incoming.each_key do |name|
            array = incoming[name]
            $log.warn("#{log_header} duplicate name <#{name}> in file <#{relative_path}> on PXE Server <#{self.name}>") if array.length > 1
            incoming[name] = array.first
          end

          incoming.each do |name, ihash|
            image = current.delete([relative_path, ihash[:label]])
            if image.nil?
              image = image_class.new
              self.pxe_images << image
            end
            stats[image.new_record? ? :adds : :updates] += 1

            image.path = relative_path
            image.parsed_contents = ihash
            image.save!
          end
        end
      rescue => err
        $log.error("#{log_header} Synchronizing PXE images on PXE Server [#{self.name}]: #{err.class.name}: #{err}")
        $log.log_backtrace(err)
      end
    end

    stats[:deletes] = current.length
    self.pxe_images.delete(current.values) unless current.empty?

    $log.info("#{log_header} Synchronizing PXE images on PXE Server [#{self.name}]... Complete - #{stats.inspect}")
  end

  def sync_windows_images
    return if self.windows_images_directory.nil?

    log_header = "MIQ(#{self.class.name}#sync_windows_images)"
    $log.info("#{log_header} Synchronizing Windows images on PXE Server [#{self.name}]...")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = self.windows_images.index_by { |i| [i.path, i.index] }

    with_depot do
      begin
        self.file_glob("#{self.windows_images_directory}/*.wim").each do |f|
          next unless self.file_file?(f)

          path = Pathname.new(f).relative_path_from(Pathname.new(self.windows_images_directory)).to_s

          wim_parser = WimParser.new(File.join(depot_root, f))
          wim_parser.xml_data["images"].each do |image_hash|
            index   = image_hash["index"]

            image   = current.delete([path, index]) || self.windows_images.build
            stats[image.new_record? ? :adds : :updates] += 1

            image.update_attributes(
              :name        => image_hash["name"],
              :description => image_hash["description"].blank? ? nil : image_hash["description"],
              :path        => path,
              :index       => index
            )
          end
        end
      rescue => err
        $log.error("#{log_header} Synchronizing Windows images on PXE Server [#{self.name}]: #{err.class.name}: #{err}")
        $log.log_backtrace(err)
      end
    end

    stats[:deletes] = current.length
    self.windows_images.delete(current.values) unless current.empty?

    $log.info("#{log_header} Synchronizing Windows images on PXE Server [#{self.name}]...Complete - #{stats.inspect}")
  end

  def read_file(filename)
    with_depot { self.file_read(filename) }
  end

  def write_file(filename, contents)
    with_depot { self.file_write(filename, contents) }
  end

  def delete_file(filename)
    with_depot { self.file_delete(filename) }
  end

  def delete_directory(directory)
    with_depot { self.directory_delete(directory) }
  end

  def create_provisioning_files(pxe_image, mac_address, windows_image = nil, customization_template = nil, substitution_options = nil)
    log_message = "MIQ(#{self.class.name}#create_provisioning_files) Creating provisioning files for PXE Image [#{pxe_image.description}], Customization Template [#{customization_template.try(:description)}], with MAC Address [#{mac_address}]"
    $log.info("#{log_message}...")
    with_depot do
      pxe_image.create_files_on_server(self, mac_address, customization_template)
      customization_template.create_files_on_server(self, pxe_image, mac_address, windows_image, substitution_options) unless customization_template.nil?
    end
    $log.info("#{log_message}...Complete")
  end

  def delete_provisioning_files(pxe_image, mac_address, windows_image = nil, customization_template = nil)
    log_message = "MIQ(#{self.class.name}#delete_provisioning_files) Deleting provisioning files for PXE Image [#{pxe_image.description}], Customization Template [#{customization_template.try(:description)}], with MAC Address [#{mac_address}]"
    $log.info("#{log_message}...")
    with_depot do
      pxe_image.delete_files_on_server(self, mac_address)
      customization_template.delete_files_on_server(self, pxe_image, mac_address, windows_image) unless customization_template.nil?
    end
    $log.info("#{log_message}...Complete")
  end
end
