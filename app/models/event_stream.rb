class EventStream < ApplicationRecord
  include Purging
  serialize :full_data

  belongs_to :target, :polymorphic => true
  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :generating_ems, :class_name => "ExtManagementSystem"

  belongs_to :vm_or_template
  alias_method :src_vm_or_template, :vm_or_template
  belongs_to :vm,           :foreign_key => :vm_or_template_id
  belongs_to :miq_template, :foreign_key => :vm_or_template_id
  belongs_to :host
  belongs_to :availability_zone
  alias_method :src_host, :host

  belongs_to :dest_vm_or_template, :class_name => "VmOrTemplate"
  belongs_to :dest_vm,             :class_name => "Vm",          :foreign_key => :dest_vm_or_template_id
  belongs_to :dest_miq_template,   :class_name => "MiqTemplate", :foreign_key => :dest_vm_or_template_id
  belongs_to :dest_host,           :class_name => "Host"

  belongs_to :service

  belongs_to :container_replicator
  belongs_to :container_group
  belongs_to :container_node

  belongs_to :physical_server
  belongs_to :physical_storage
  belongs_to :physical_chassis, :inverse_of => :event_streams
  belongs_to :physical_switch, :inverse_of => :event_streams

  virtual_delegate :name, :to => :ext_management_system, :prefix => true, :allow_nil => true, :type => :string
  virtual_delegate :name, :to => :host,                  :prefix => true, :allow_nil => true, :type => :string
  virtual_delegate :name, :to => :vm_or_template,        :prefix => true, :allow_nil => true, :type => :string

  virtual_column :group,       :type => :string
  virtual_column :group_level, :type => :string
  virtual_column :group_name,  :type => :string

  after_commit :emit_notifications, :on => :create

  DEFAULT_GROUP_NAME     = :other
  DEFAULT_GROUP_NAME_STR = N_("Other")
  DEFAULT_GROUP_LEVEL    = :detail

  def self.description
    raise NotImplementedError, "Description must be implemented in a subclass"
  end

  def self.class_group_levels
    []
  end

  def self.clear_event_groups_cache
    descendants.each { |c| c.clear_event_groups_cache if c.respond_to?(:clear_event_groups_cache) }
  end

  def self.group_levels
    class_group_levels + [DEFAULT_GROUP_LEVEL]
  end

  def emit_notifications
    Notification.emit_for_event(self)
  rescue => err
    _log.log_backtrace(err)
  end

  def self.event_groups
    raise NotImplementedError, "event_groups must be implemented in a subclass"
  end

  def group
    group_and_level.first
  end

  def group_level
    group_and_level.last
  end

  private def group_and_level
    @group_and_level ||= self.class.group_and_level(event_type)
  end

  def group_name
    @group_name ||= self.class.group_name(group)
  end

  def self.group_and_level(event_type)
    # Given a specific event_type, return the group and level for it
    raise NotImplementedError, "group_and_level must be implemented in a subclass"
  end

  def self.group_name(group)
    # Return the name for a specific event group
    raise NotImplementedError, "group_name must be implemented in a subclass"
  end

  def self.timeline_classes
    EventStream.subclasses.select { |e| e.respond_to?(:group_names_and_levels) }
  end

  def self.default_group_names_and_levels
    {
      :description  => description,
      :group_names  => {DEFAULT_GROUP_NAME => DEFAULT_GROUP_NAME.to_s.capitalize},
      :group_levels => {}
    }.freeze
  end

  def self.timeline_options
    timeline_classes.map { |c| [c.name.to_sym, c.group_names_and_levels] }.to_h
  end
end
