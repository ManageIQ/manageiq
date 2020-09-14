class PxeServer < ApplicationRecord
  autoload :WimParser, "win32/wim_parser" # via manageiq-gems-pending

  include FileDepotMixin

  alias_attribute :description, :name

  default_value_for :customization_directory, ""

  serialize :visibility

  acts_as_miq_taggable

  validates :uri, :presence => true
  validates :name, :presence => true, :uniqueness_when_changed => true

  has_many :pxe_menus,      :dependent => :destroy
  has_many :pxe_images,     :dependent => :destroy
  has_many :advertised_pxe_images, -> { where("pxe_menu_id IS NOT NULL") }, :class_name => "PxeImage"
  has_many :discovered_pxe_images, -> { where(:pxe_menu_id => nil) }, :class_name => "PxeImage"
  has_many :windows_images, :dependent => :destroy

  def images
    pxe_images + windows_images
  end

  def advertised_images
    advertised_pxe_images + windows_images
  end

  def discovered_images
    discovered_pxe_images + windows_images
  end

  def default_pxe_image_for_windows=(image)
    image.update(:default_for_windows => true)
    clear_association_cache
  end

  def default_pxe_image_for_windows
    pxe_images.find_by(:default_for_windows => true)
  end

  def synchronize_advertised_images
    pxe_menus.each(&:synchronize)
    sync_windows_images
    clear_association_cache
    update_attribute(:last_refresh_on, Time.now.utc)
  end

  def synchronize_advertised_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "synchronize_advertised_images"
    )
  end

  def sync_images
    sync_pxe_images
    sync_windows_images
    clear_association_cache
    update_attribute(:last_refresh_on, Time.now.utc)
  end

  def sync_images_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "sync_images"
    )
  end

  def sync_pxe_images
    _log.info("Synchronizing PXE images on PXE Server [#{name}]...")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = pxe_images.where(:pxe_menu_id => nil).index_by { |i| [i.path, i.name] }

    with_depot do
      begin
        file_glob("#{pxe_directory}/*").each do |f|
          next unless self.file_file?(f)

          relative_path = Pathname.new(f).relative_path_from(Pathname.new(pxe_directory)).to_s

          contents    = file_read(f)
          menu_class  = PxeMenu.class_from_contents(contents)
          image_class = menu_class.corresponding_image
          image_list  = image_class.parse_contents(contents, File.basename(f))

          # Deal with multiple images with the same label in a file
          incoming = image_list.group_by { |h| h[:label] }
          incoming.each_key do |name|
            array = incoming[name]
            _log.warn("duplicate name <#{name}> in file <#{relative_path}> on PXE Server <#{self.name}>") if array.length > 1
            incoming[name] = array.first
          end

          incoming.each do |_name, ihash|
            image = current.delete([relative_path, ihash[:label]])
            if image.nil?
              image = image_class.new
              pxe_images << image
            end
            stats[image.new_record? ? :adds : :updates] += 1

            image.path = relative_path
            image.parsed_contents = ihash
            image.save!
          end
        end
      rescue => err
        _log.error("Synchronizing PXE images on PXE Server [#{self.name}]: #{err.class.name}: #{err}")
        _log.log_backtrace(err)
      end
    end

    stats[:deletes] = current.length
    pxe_images.delete(current.values) unless current.empty?

    _log.info("Synchronizing PXE images on PXE Server [#{self.name}]... Complete - #{stats.inspect}")
  end

  def sync_windows_images
    return if windows_images_directory.nil?

    _log.info("Synchronizing Windows images on PXE Server [#{name}]...")

    stats = {:adds => 0, :updates => 0, :deletes => 0}
    current = windows_images.index_by { |i| [i.path, i.index] }

    with_depot do
      begin
        file_glob("#{windows_images_directory}/*.wim").each do |f|
          next unless self.file_file?(f)

          path = Pathname.new(f).relative_path_from(Pathname.new(windows_images_directory)).to_s

          wim_parser = WimParser.new(File.join(depot_root, f))
          wim_parser.xml_data["images"].each do |image_hash|
            index   = image_hash["index"]

            image   = current.delete([path, index]) || windows_images.build
            stats[image.new_record? ? :adds : :updates] += 1

            image.update(
              :name        => image_hash["name"],
              :description => image_hash["description"].blank? ? nil : image_hash["description"],
              :path        => path,
              :index       => index
            )
          end
        end
      rescue => err
        _log.error("Synchronizing Windows images on PXE Server [#{name}]: #{err.class.name}: #{err}")
        _log.log_backtrace(err)
      end
    end

    stats[:deletes] = current.length
    windows_images.delete(current.values) unless current.empty?

    _log.info("Synchronizing Windows images on PXE Server [#{name}]...Complete - #{stats.inspect}")
  end

  def read_file(filename)
    with_depot { file_read(filename) }
  end

  def write_file(filename, contents)
    with_depot { file_write(filename, contents) }
  end

  def delete_file(filename)
    with_depot { file_delete(filename) }
  end

  def delete_directory(directory)
    with_depot { directory_delete(directory) }
  end

  def create_provisioning_files(pxe_image, mac_address, windows_image = nil, customization_template = nil, substitution_options = nil)
    log_message = "Creating provisioning files for PXE Image [#{pxe_image.description}], Customization Template [#{customization_template.try(:description)}], with MAC Address [#{mac_address}]"
    _log.info("#{log_message}...")
    with_depot do
      pxe_image.create_files_on_server(self, mac_address, customization_template)
      customization_template.create_files_on_server(self, pxe_image, mac_address, windows_image, substitution_options) unless customization_template.nil?
    end
    _log.info("#{log_message}...Complete")
  end

  def delete_provisioning_files(pxe_image, mac_address, windows_image = nil, customization_template = nil)
    log_message = "Deleting provisioning files for PXE Image [#{pxe_image.description}], Customization Template [#{customization_template.try(:description)}], with MAC Address [#{mac_address}]"
    _log.info("#{log_message}...")
    with_depot do
      pxe_image.delete_files_on_server(self, mac_address)
      customization_template.delete_files_on_server(self, pxe_image, mac_address, windows_image) unless customization_template.nil?
    end
    _log.info("#{log_message}...Complete")
  end

  def ensure_menu_list(menu_list)
    current_menus = pxe_menus.map(&:file_name)
    to_destroy = current_menus - menu_list
    to_create = menu_list - current_menus
    transaction do
      pxe_menus.where(:file_name => to_destroy).destroy_all
      to_create.each { |menu| pxe_menus << PxeMenu.create!(:file_name => menu) }
    end
  end

  def self.display_name(number = 1)
    n_('PXE Server', 'PXE Servers', number)
  end
end
