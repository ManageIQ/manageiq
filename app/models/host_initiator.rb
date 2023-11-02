class HostInitiator < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin
  include EmsRefreshMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage, :inverse_of => :host_initiators
  belongs_to :host_initiator_group

  has_many :san_addresses, :as => :owner, :dependent => :destroy
  has_many :volume_mappings, :dependent => :destroy
  has_many :cloud_volumes, :through => :volume_mappings

  virtual_total :v_total_addresses, :san_addresses

  acts_as_miq_taggable

  def my_zone
    ems = ext_management_system
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:HostInitiator)
  end

  def self.create_host_initiator_queue(userid, ext_management_system, options = {})
    task_opts = {
      :action => "creating HostInitiator for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => 'HostInitiator',
      :method_name => 'create_host_initiator',
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_host_initiator(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find_by(:id => ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:HostInitiator)
    klass.raw_create_host_initiator(ext_management_system, options)
  end

  def self.raw_create_host_initiator(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_host_initiator must be implemented in a subclass")
  end

  def raw_delete_host_initiator
    raise NotImplementedError, _("raw_delete_host_initiator must be implemented in a subclass")
  end

  def delete_host_initiator
    raw_delete_host_initiator
  end

  # Delete a storage system as a queued task and return the task id. The queue
  # name and the queue zone are derived from the EMS, and a userid is mandatory.
  def delete_host_initiator_queue(userid)
    task_opts = {
      :action => "deleting host initiator for user #{userid}",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_host_initiator',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => ext_management_system.queue_name_for_ems_operations,
      :zone        => ext_management_system.my_zone,
      :args        => []
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end
end
