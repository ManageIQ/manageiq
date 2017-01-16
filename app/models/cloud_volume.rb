class CloudVolume < ApplicationRecord
  include_concern 'Operations'

  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include AvailabilityMixin
  include SupportsFeatureMixin
  include CloudTenancyMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :availability_zone
  belongs_to :cloud_tenant
  belongs_to :base_snapshot, :class_name => 'CloudVolumeSnapshot', :foreign_key => :cloud_volume_snapshot_id
  has_many   :cloud_volume_backups
  has_many   :cloud_volume_snapshots
  has_many   :attachments, :class_name => 'Disk', :as => :backing
  has_many   :hardwares, :through => :attachments
  has_many   :vms, :through => :hardwares, :foreign_key => :vm_or_template_id

  acts_as_miq_taggable

  def self.available
    left_outer_joins(:attachments).where("disks.backing_id" => nil)
  end

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from OrchesTration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::CloudVolume
  end

  def self.create_volume_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating Cloud Volume for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => "CloudVolume",
      :method_name => 'create_volume',
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_volume(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?
    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

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

  def update_volume_queue(userid, options = {})
    task_opts = {
      :action => "updating Cloud Volume for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
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

  def delete_volume_queue(userid)
    task_opts = {
      :action => "deleting Cloud Volume for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_volume',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
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

  def available_vms
    raise NotImplementedError, _("available_vms must be implemented in a subclass")
  end
end
