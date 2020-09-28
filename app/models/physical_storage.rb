class PhysicalStorage < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_rack
  belongs_to :physical_chassis, :inverse_of => :physical_storages

  has_many :storage_resources, :dependent => :destroy
  belongs_to :physical_storage_family, :inverse_of => :physical_storages

  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false

  has_many :canisters, :dependent => :destroy, :inverse_of => false
  has_many :physical_disks, :dependent => :destroy, :inverse_of => :physical_storage

  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :hardware, :through => :computer_system

  has_many :canister_computer_systems, :through => :canisters, :source => :computer_system
  has_many :guest_devices, :through => :hardware

  supports :refresh_ems
  supports_not :create
  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def refresh_ems
    unless ext_management_system
      raise _("No Provider defined")
    end
    unless ext_management_system.has_credentials?
      raise _("No Provider credentials defined")
    end
    unless ext_management_system.authentication_status_ok?
      raise _("Provider failed last authentication check")
    end

    EmsRefresh.queue_refresh(ext_management_system)
  end

  def self.create_physical_storage_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating PhysicalStorage for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'PhysicalStorage',
      :method_name => 'create_physical_storage',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_physical_storage(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = class_by_ems(ext_management_system)
    klass.raw_create_physical_storage(ext_management_system, options)
  end

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::PhysicalStorage
  end

  def self.raw_create_physical_storage(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_physical_storage must be implemented in a subclass")
  end

  def update_physical_storage_queue(userid, options = {})
    task_opts = {
      :action => "updating PhysicalStorage for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_physical_storage',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_physical_storage(options = {})
    raw_update_physical_storage(options)
  end

  def validate_update_physical_storage
    validate_unsupported("Update Volume Operation")
  end

  def raw_update_physical_storage(_options = {})
    raise NotImplementedError, _("raw_update_volume must be implemented in a subclass")
  end
end
