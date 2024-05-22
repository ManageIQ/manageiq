class PhysicalStorage < ApplicationRecord
  include SupportsFeatureMixin
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin
  include EmsRefreshMixin
  include EventMixin

  # The physical-storage is expected to have san_addresses of its own in the future (The real addresses through which it actually connects to the SAN).
  # Therefore, the name san_addresses is reserved for the physical-storages actual san-addresses, and for all of the san_addresses configured in the physical-storage's host_initiators we refer as registered_initiator_addresses.

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_rack
  belongs_to :physical_chassis, :inverse_of => :physical_storages
  belongs_to :physical_storage_family, :inverse_of => :physical_storages

  has_one :hardware, :through => :computer_system
  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :asset_detail, :as => :resource, :dependent => :destroy, :inverse_of => false

  has_many :storage_resources, :dependent => :destroy
  has_many :host_initiators, :dependent => :destroy
  has_many :host_initiator_groups, :dependent => :destroy
  has_many :registered_initiator_addresses, :through => :host_initiators, :source => :san_addresses
  has_many :canisters, :dependent => :destroy, :inverse_of => false
  has_many :physical_disks, :dependent => :destroy, :inverse_of => :physical_storage
  has_many :canister_computer_systems, :through => :canisters, :source => :computer_system
  has_many :guest_devices, :through => :hardware
  has_many :wwpn_candidates, :dependent => :destroy
  has_many :event_streams, :dependent => :nullify

  supports :timeline

  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def raw_delete_physical_storage
    raise NotImplementedError, _("raw_delete_physical_storage must be implemented in a subclass")
  end

  def delete_physical_storage
    raw_delete_physical_storage
  end

  # Delete a storage system as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  def delete_physical_storage_queue(userid)
    task_opts = {
      :action => "deleting PhysicalStorage for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_physical_storage',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.raw_validate_physical_storage(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_validate_physical_storage must be implemented in a subclass")
  end

  def self.validate_physical_storage(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:PhysicalStorage)
    klass.raw_validate_physical_storage(ext_management_system, options)
  end

  def self.validate_storage_queue(userid, ext_management_system, options = {})
    options["password"] = ManageIQ::Password.encrypt(options["password"])

    task_opts = {
      :action => "validating PhysicalStorage for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => 'PhysicalStorage',
      :method_name => 'validate_physical_storage',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_physical_storage_queue(userid, ext_management_system, options = {})
    options["password"] = ManageIQ::Password.encrypt(options["password"])

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

    klass = ext_management_system.class_by_ems(:PhysicalStorage)
    klass.raw_create_physical_storage(ext_management_system, options)
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:PhysicalStorage)
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

  def raw_update_physical_storage(_options = {})
    raise NotImplementedError, _("raw_update_physical_storage must be implemented in a subclass")
  end

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      ["#{events_table_name(assoc)}.physical_storage_id = ?", id]
    when :policy_events
      ["target_id = ? and target_class = ? ", id, self.class.base_class.name]
    end
  end
end
