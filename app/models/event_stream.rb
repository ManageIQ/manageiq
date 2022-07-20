class EventStream < ApplicationRecord
  include_concern 'Purging'
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

  virtual_column :group,       :type => :string
  virtual_column :group_level, :type => :string
  virtual_column :group_name,  :type => :string

  after_commit :emit_notifications, :on => :create

  DEFAULT_GROUP_NAME  = :other
  DEFAULT_GROUP_LEVEL = :detail

  def self.description
    raise NotImplementedError, "Description must be implemented in a subclass"
  end

  def self.class_group_levels
    []
  end

  def self.group_levels
    class_group_levels + [DEFAULT_GROUP_LEVEL]
  end

  def emit_notifications
    Notification.emit_for_event(self)
  rescue => err
    _log.log_backtrace(err)
  end

  # TODO: Consider moving since this is EmsEvent specific. group, group_level and group_name exposed as a virtual columns for reports/api.
  def self.event_groups
    core_event_groups = ::Settings.event_handling.event_groups.to_hash
    Settings.ems.each_with_object(core_event_groups) do |(_provider_type, provider_settings), event_groups|
      provider_event_groups = provider_settings.fetch_path(:event_handling, :event_groups)
      next unless provider_event_groups
      DeepMerge.deep_merge!(
        provider_event_groups.to_hash, event_groups,
        :preserve_unmergeables => false,
        :overwrite_arrays      => false
      )
    end
  end

  # TODO: Consider moving since this is EmsEvent specific. group, group_level and group_name exposed as a virtual columns for reports/api.
  def self.group_and_level(event_type)
    level = DEFAULT_GROUP_LEVEL # the level is detail as default
    egroups = event_groups

    group = egroups.detect do |_, value|
      group_levels
        .detect { |lvl| value[lvl]&.any? { |typ| !typ.starts_with?("/") && typ == event_type } }
        .tap { |level_found| level = level_found || level }
    end&.first

    group ||= egroups.detect do |_, value|
      group_levels
        .detect { |lvl| value[lvl]&.any? { |typ| typ.starts_with?("/") && Regexp.new(typ[1..-2]).match?(event_type) } }
        .tap { |level_found| level = level_found || level }
    end&.first

    group ||= DEFAULT_GROUP_NAME
    return group, level
  end

  def self.group_name(group)
    return if group.nil?
    group = event_groups[group.to_sym]
    group.nil? ? DEFAULT_GROUP_NAME.to_s.capitalize : group[:name]
  end

  # TODO: Consider moving since this is EmsEvent specific. group, group_level and group_name exposed as a virtual columns for reports/api.
  def group
    return @group unless @group.nil?
    @group, @group_level = self.class.group_and_level(event_type)
    @group
  end

  # TODO: Consider moving since this is EmsEvent specific. group, group_level and group_name exposed as a virtual columns for reports/api.
  def group_level
    return @group_level unless @group_level.nil?
    @group, @group_level = self.class.group_and_level(event_type)
    @group_level
  end

  # TODO: Consider moving since this is EmsEvent specific. group, group_level and group_name exposed as a virtual columns for reports/api.
  def group_name
    @group_name ||= self.class.group_name(group)
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
