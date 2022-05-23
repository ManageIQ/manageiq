class PlacementGroup < ApplicationRecord
  acts_as_miq_taggable
  include SupportsFeatureMixin
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::CloudManager", :inverse_of => :placement_groups
  belongs_to :availability_zone
  belongs_to :cloud_tenant

  has_many :vms, :dependent => :nullify

  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:PlacementGroup)
  end

  def self.my_zone(ems)
    # TODO(pblaho): find unified way how to do that
    ems ? ems.my_zone : MiqServer.my_zone
  end

  def my_zone
    self.class.my_zone(ext_management_system)
  end

  def self.create_placement_group_queue(userid, ext_management_system, options = {})
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    task_opts = {
      :action => "creating Placement Group for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'create_placement_group',
      :role        => 'ems_operations',
      :queue_name  => queue_name_for_ems_operations,
      :zone        => my_zone,
      :args        => [ext_management_system.id, options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_placement_group(ems_id, options = {})
    raise ArgumentError, _("ems_id cannot be nil") if ems_id.nil?

    ext_management_system = ExtManagementSystem.find(ems_id)
    raise ArgumentError, _("ext_management_system cannot be found") if ext_management_system.nil?

    klass = ext_management_system.class_by_ems(:Placement)
    klass.raw_create_placement_group(ext_management_system, options)
  end

  def self.raw_create_placement_group(_ext_management_system, _options = {})
    raise NotImplementedError, _("raw_create_placement_group must be implemented in a subclass")
  end

  def delete_placement_group_queue(userid)
    task_opts = {
      :action => "deleting Placement Group for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'delete_placement_group',
      :instance_id => id,
      :role        => 'ems_operations',
      :queue_name  => queue_name_for_ems_operations,
      :zone        => my_zone,
      :args        => []
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def delete_placement_group
    raw_delete_placement_group
  end

  def raw_delete_placement_group
    raise NotImplementedError, _("raw_delete_placement_group must be implemented in a subclass")
  end
end
