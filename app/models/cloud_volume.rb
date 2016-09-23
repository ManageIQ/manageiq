class CloudVolume < ApplicationRecord
  include_concern 'Operations'

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include AvailabilityMixin
  include SupportsFeatureMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::StorageManager"
  belongs_to :availability_zone
  belongs_to :cloud_tenant
  belongs_to :base_snapshot, :class_name => 'CloudVolumeSnapshot', :foreign_key => :cloud_volume_snapshot_id
  has_many   :cloud_volume_backups
  has_many   :cloud_volume_snapshots
  has_many   :attachments, :class_name => 'Disk', :as => :backing
  has_many   :hardwares, :through => :attachments
  has_many   :vms, :through => :hardwares, :foreign_key => :vm_or_template_id

  acts_as_miq_taggable

  supports :cloud_volume_backup_create do
    unsupported_reason_add(:cloud_volume_backup_create, _("Backup unsupported")) unless validate_backup_create
  end

  supports :cloud_volume_backup_restore do
    unsupported_reason_add(:cloud_volume_backup_restore, _("Backup unsupported")) unless validate_backup_restore
  end

  def self.available
    joins("LEFT OUTER JOIN disks ON disks.backing_id = cloud_volumes.id")
      .where("disks.backing_id" => nil)
  end

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from OrchesTration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::CloudVolume
  end

  def self.create_volume(ext_management_system, options = {})
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    tenant = options[:cloud_tenant]

    created_volume = klass.raw_create_volume(ext_management_system, options)

    klass.create(
      :name                  => created_volume[:name],
      :ems_ref               => created_volume[:ems_ref],
      :status                => created_volume[:status],
      :size                  => options[:size].to_i.gigabytes,
      :ext_management_system => ext_management_system,
      :cloud_tenant          => tenant)
  end

  def self.validate_create_volume(ext_management_system)
    klass = class_by_ems(ext_management_system)
    return klass.validate_create_volume(ext_management_system) if ext_management_system &&
                                                                  klass.respond_to?(:validate_create_volume)
    validate_unsupported("Create Volume Operation")
  end

  def self.raw_create_volume(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_volume must be implemented in a subclass")
  end

  def update_volume(options = {})
    raw_update_volume(options)
  end

  def validate_update_volume
    validate_unsupported("Update Volume Operation")
  end

  def raw_update_volume(_options = {})
    raise NotImplementedError, _("raw_update_volume must be implemented in a subclass")
  end

  def delete_volume
    raw_delete_volume
  end

  def validate_delete_volume
    validate_unsupported("Delete Volume Operation")
  end

  def raw_delete_volume
    raise NotImplementedError, _("raw_delete_volume must be implemented in a subclass")
  end

  def backup_create(options = {})
    raw_backup_create(options)
  end

  def validate_backup_create
    false
  end

  def raw_backup_create(_options = {})
    raise NotImplementedError, _("raw_backup_create must be implemented in a subclass")
  end

  def backup_restore(backup_id)
    raw_backup_restore(backup_id)
  end

  def validate_backup_restore
    false
  end

  def raw_backup_restore(_backup_id)
    raise NotImplementedError, _("raw_backup_restore must be implemented in a subclass")
  end
end
