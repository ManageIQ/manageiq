class HostInitiatorGroup < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage, :inverse_of => :host_initiator_groups

  has_many :host_initiators, :dependent => :nullify
  has_many :san_addresses, :through => :host_initiators
  has_many :volume_mappings, :dependent => :destroy
  has_many :cloud_volumes, :through => :volume_mappings

  virtual_total :v_total_addresses, :san_addresses

  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:HostInitiatorGroup)
  end

  def self.create_host_initiator_group_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating HostInitiatorGroup for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'HostInitiatorGroup',
      :method_name => 'create_host_initiator_group',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_host_initiator_group(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:HostInitiatorGroup)
    klass.raw_create_host_initiator_group(ext_management_system, options)
  end

  def self.raw_create_host_initiator_group(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_host_initiator_group must be implemented in a subclass")
  end

  def delete_host_initiator_group_queue(userid)
    task_opts = {
      :action => "deleting Host Initiator Group for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_host_initiator_group',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def raw_delete_host_initiator_group
    raise NotImplementedError, _("raw_delete_host_initiator_group must be implemented in a subclass")
  end

  def delete_host_initiator_group
    raw_delete_host_initiator_group
  end

  def update_host_initiator_group_queue(userid, options = {})
    task_opts = {
      :action => "updating Host Initiator Group for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'update_host_initiator_group',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def update_host_initiator_group(options = {})
    raw_update_host_initiator_group(options)
  end

  def raw_update_host_initiator_group(_options = {})
    raise NotImplementedError, _("raw_update_host_initiator_group must be implemented in a subclass")
  end
end
