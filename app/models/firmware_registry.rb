class FirmwareRegistry < ApplicationRecord
  include NewWithTypeStiMixin

  has_many :firmware_binaries, :dependent => :destroy
  has_one :endpoint, :as => :resource, :dependent => :destroy, :inverse_of => :resource
  has_one :authentication, :as => :resource, :dependent => :destroy, :inverse_of => :resource

  validates :name, :presence => true, :uniqueness_when_changed => true

  def sync_fw_binaries_queue
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'sync_fw_binaries'
    )
  end

  def sync_fw_binaries
    _log.info("Synchronizing FirmwareBinaries from #{self.class.name} [#{id}|#{name}]...")
    sync_fw_binaries_raw
    self.last_refresh_error = nil
    _log.info("Synchronizing FirmwareBinaries from #{self.class.name} [#{id}|#{name}]... Complete")
  rescue MiqException::Error => e
    self.last_refresh_error = e
  ensure
    self.last_refresh_on = Time.now.utc
    save!
  end

  def sync_fw_binaries_raw
    raise NotImplementedError, 'Must be implemented in subclass'
  end

  def self.create_firmware_registry(options)
    klass = options.delete(:type).constantize
    options = klass.validate_options(options.deep_symbolize_keys)
    klass.do_create_firmware_registry(options).tap(&:sync_fw_binaries_queue)
  end

  def self.validate_options(options)
    options
  end

  def self.do_create_firmware_registry(_options)
    raise NotImplementedError, 'Must be implemented in subclass'
  end

  def self.display_name(number = 1)
    n_('Firmware Registry', 'Firmware Registries', number)
  end
end
