class EventStream < ApplicationRecord
  serialize :full_data

  belongs_to :target, :polymorphic => true
  belongs_to :ext_management_system, :foreign_key => :ems_id

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

  belongs_to :middleware_server, :foreign_key => :middleware_server_id

  after_commit :emit_notifications, :on => :create

  def emit_notifications
    Notification.emit_for_event(self)
  rescue => err
    _log.log_backtrace(err)
  end

  #
  # Purging methods
  #

  def self.keep_ems_events
    ::Settings.ems_events.history.keep_ems_events
  end

  def self.purge_date
    keep = keep_ems_events.to_i_with_method.seconds
    keep = 6.months if keep == 0
    keep.ago.utc
  end

  def self.purge_window_size
    ::Settings.ems_events.history.purge_window_size
  end

  def self.purge_timer
    purge_queue(purge_date)
  end

  def self.purge_queue(ts)
    MiqQueue.put(
      :class_name  => name,
      :method_name => "purge",
      :role        => "event",
      :queue_name  => "ems",
      :args        => [ts],
    )
  end

  def self.purge(older_than, window = nil, limit = nil)
    _log.info("Purging #{limit || "all"} events older than [#{older_than}]...")

    window ||= purge_window_size

    total = where(arel_table[:timestamp].lteq(older_than)).delete_in_batches(window, limit) do |count, _total|
      _log.info("Purging #{count} events.")
    end

    _log.info("Purging #{limit || "all"} events older than [#{older_than}]...Complete - Deleted #{total} records")
  end
end
