class MiqAlert < ApplicationRecord
  include UuidMixin

  SEVERITIES = [nil, "info", "warning", "error"]

  serialize :miq_expression
  serialize :hash_expression
  serialize :options

  validates_presence_of     :description, :guid
  validates_uniqueness_of   :description, :guid
  validate :validate_automate_expressions
  validate :validate_single_expression
  validates :severity, :inclusion => { :in => SEVERITIES }

  has_many :miq_alert_statuses, :dependent => :destroy
  before_save :set_responds_to_events

  attr_accessor :reserved

  BASE_TABLES = %w(
    Vm
    Host
    Storage
    EmsCluster
    ExtManagementSystem
    MiqServer
    ContainerNode
    ContainerProject
  )

  def self.base_tables
    BASE_TABLES
  end

  def self.display_name
    "Alert"
  end

  acts_as_miq_set_member

  ASSIGNMENT_PARENT_ASSOCIATIONS = [:host, :ems_cluster, :ext_management_system, :my_enterprise]

  HOURLY_TIMER_EVENT   = "_hourly_timer_"

  cache_with_timeout(:alert_assignments) { Hash.new }

  virtual_column :based_on,               :type => :string
  virtual_column :evaluation_description, :type => :string
  virtual_column :notify_automate,        :type => :boolean
  virtual_column :notify_email,           :type => :boolean
  virtual_column :notify_evm_event,       :type => :boolean
  virtual_column :notify_snmp,            :type => :boolean

  def based_on
    Dictionary.gettext(db, :type => :model)
  end

  def expression=(exp)
    if exp.kind_of?(MiqExpression)
      self.miq_expression = exp
    elsif exp.kind_of?(Hash)
      self.hash_expression = exp
    end
  end

  def expression
    miq_expression || hash_expression
  end

  def miq_expression=(exp)
    super(exp.nil? || exp.kind_of?(MiqExpression) ? exp : MiqExpression.new(exp))
  end

  def evaluation_description
    return "Expression (Custom)" if     miq_expression
    return "None"                unless hash_expression && hash_expression.key?(:eval_method)

    exp = self.class.expression_by_name(hash_expression[:eval_method])
    exp ? exp[:description] : "Unknown"
  end

  # Define methods for notify_* virtual columns
  [:automate, :email, :evm_event, :snmp].each do |n|
    define_method("notify_#{n}") do
      (options || {}).has_key_path?(:notifications, n)
    end
  end

  def miq_actions
    []
  end
  alias_method :actions, :miq_actions
  alias_method :owning_miq_actions, :miq_actions

  def set_responds_to_events
    events = responds_to_events_from_expression
    self.responds_to_events = events unless events.nil?
  end

  def validate_automate_expressions
    # if always_evaluate = true, delay_next_evaluation must be 0
    valid = true
    automate_expression = if hash_expression && self.class.expression_by_name(hash_expression[:eval_method])
                            self.class.expression_by_name(hash_expression[:eval_method])
                          else
                            {}
                          end
    next_frequency = (options || {}).fetch_path(:notifications, :delay_next_evaluation)
    if automate_expression[:always_evaluate] && next_frequency != 0
      valid = false
      errors.add(:notifications, "Datawarehouse alerts must have a 0 notification frequency")
    end
    valid
  end

  def validate_single_expression
    if miq_expression && hash_expression
      errors.add("Alert", "must not have both miq_expression and hash_expression set")
    end
  end

  def self.assigned_to_target(target, event = nil)
    # Get all assigned, enabled alerts based on target class and event

    # event can be nil, so the compact removes event if it is nil
    key  = [target.class.base_model.name, target.id, event].compact.join("_")

    alert_assignments[key] ||= begin
      profiles  = MiqAlertSet.assigned_to_target(target)
      alert_ids = profiles.flat_map { |p| p.members.pluck(:id) }.uniq

      if alert_ids.empty?
        none
      else
        scope = where(:id => alert_ids, :enabled => true, :db => target.class.base_model.name)
        scope = scope.where("responds_to_events like ?", "%#{event}%") if event
        scope
      end
    end
  end

  def self.target_needs_realtime_capture?(target)
    !assigned_to_target(target, "#{target.class.base_model.name.underscore}_perf_complete").empty?
  end

  def self.normalize_target(target)
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by(:id => id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end
    target
  end

  def self.evaluate_alerts(target, event, inputs = {})
    target = normalize_target(target)

    log_header = "[#{event}]"
    log_target = "Target: #{target.class.name} Name: [#{target.name}], Id: [#{target.id}]"
    _log.info("#{log_header} #{log_target}")

    assigned_to_target(target, event).each do |a|
      next if a.postpone_evaluation?(target)
      _log.info("#{log_header} #{log_target} Queuing evaluation of Alert: [#{a.description}]")
      a.evaluate_queue(target, inputs)
    end
  end

  def self.evaluate_hourly_timer
    _log.info("Starting")

    # Find all active alerts that respond to _hourly_timer_ that have assignments
    # assignments = MiqAlert.assignments(:conditions => ["enabled = ? and responds_to_events like ?", true, "%#{HOURLY_TIMER_EVENT}%"])
    # TODO: Optimize to filter out sets that don't have any enabled alerts that respond to HOURLY_TIMER_EVENT
    assignments = MiqAlertSet.assignments

    zone = MiqServer.my_server.zone

    # Get list of targets from assigned profiles
    targets = []
    assignments.values.flatten.uniq.each do |prof|
      prof.miq_alerts.each do |a|
        next unless a.enabled? && a.responds_to_events && a.responds_to_events.include?(HOURLY_TIMER_EVENT)

        # Targets may come from tables such as:
        # ems_clusters, storages, hosts, ext_management_systems, miq_servers, vms
        table_name = a.db.constantize.table_name
        targets += zone.public_send(table_name)
        targets += Zone.public_send("#{table_name}_without_a_zone") if Zone.respond_to?("#{table_name}_without_a_zone")
      end
    end

    # Call evaluate_queue for each alert/target
    targets.uniq.each { |t| evaluate_alerts(t, HOURLY_TIMER_EVENT) }

    _log.info("Complete")
  end

  def evaluate_queue(targets, inputs = {})
    targets.to_miq_a.each do |target|
      zone = target.respond_to?(:my_zone) ? target.my_zone : MiqServer.my_zone
      MiqQueue.put_unless_exists(
        :class_name  => self.class.name,
        :instance_id => id,
        :method_name => "evaluate",
        :args        => [[target.class.name, target.id], inputs],
        :zone        => zone
      )
    end
  end

  def postpone_evaluation?(target)
    # TODO: Are there some alerts that we always want to evaluate?

    # If a miq alert status exists for our resource and alert, and it has not been delay_next_evaluation seconds since
    # it was evaluated, return true so we can skip evaluation
    delay_next_evaluation = (options || {}).fetch_path(:notifications, :delay_next_evaluation)
    start_skipping_at = Time.now.utc - (delay_next_evaluation || 10.minutes).to_i
    statuses_not_expired = miq_alert_statuses.where(:resource => target, :result => true)
                           .where(miq_alert_statuses.arel_table[:evaluated_on].gt(start_skipping_at))

    if statuses_not_expired.count > 0
      _log.info("Skipping re-evaluation of Alert [#{description}] for target: [#{target.name}] with delay_next_evaluation [#{delay_next_evaluation}]")
      return true
    else
      return false
    end
  end

  def evaluate(target, inputs = {})
    target = self.class.normalize_target(target)

    return if self.postpone_evaluation?(target)

    _log.info("Evaluating Alert [#{description}] for target: [#{target.name}]...")
    result = eval_expression(target, inputs)
    _log.info("Evaluating Alert [#{description}] for target: [#{target.name}]... Result: [#{result}]")

    # If we are alerting, invoke the alert actions, then add a status so we can limit how often to alert
    # Otherwise, destroy this alert's statuses for our target
    invoke_actions(target, inputs) if result
    add_status_post_evaluate(target, result, inputs[:ems_event])
    result
  end

  def add_status_post_evaluate(target, result, event)
    status_description, event_severity, url, resolved = event.try(:parse_event_metadata)
    ems_ref = event.try(:ems_ref)
    status = miq_alert_statuses.find_or_initialize_by(:resource => target, :event_ems_ref => ems_ref)
    status.result = result
    status.ems_id = target.try(:ems_id)
    status.ems_id ||= target.id if target.is_a?(ExtManagementSystem)
    status.description = status_description || description
    status.severity = severity
    status.severity = event_severity unless event_severity.blank?
    status.url = url unless url.blank?
    status.event_ems_ref = ems_ref unless ems_ref.blank?
    status.resolved = resolved
    status.evaluated_on = Time.now.utc
    status.save!
    miq_alert_statuses << status
  end

  def invoke_actions(target, inputs = {})
    build_actions.each do |a|
      if a.kind_of?(MiqAction)
        inputs = inputs.merge(:policy => self, :event => MiqEventDefinition.new(:name => "AlertEvent", :description => "Alert condition met"))
        a.invoke(target, inputs.merge(:result => true, :sequence => a.sequence, :synchronous => false))
      else
        next if a == :delay_next_evaluation
        method = "invoke_#{a}"
        unless self.respond_to?(method)
          _log.warn("Unknown notification type: [#{a}], skipping invocation")
          next
        end
        send(method, target, inputs)
      end
    end
  rescue MiqException::StopAction => err
    _log.error("Stopping action invocation [#{err.message}]")
    return
  rescue MiqException::UnknownActionRc => err
    _log.error("Aborting action invocation [#{err.message}]")
    raise
  rescue MiqException::PolicyPreventAction => err
    _log.info("[#{err}]")
    raise
  end

  def invoke_automate(target, inputs)
    event  = options.fetch_path(:notifications, :automate, :event_name)
    event_obj = CustomEvent.create(
      :event_type => event,
      :target     => target,
      :source     => 'Alert'
    )

    inputs = {
      :miq_alert_description      => description,
      :miq_alert_id               => id,
      :alert_guid                 => guid,
      'EventStream::event_stream' => event_obj.id,
      :event_stream_id            => event_obj.id
    }

    MiqQueue.put(
      :class_name  => "MiqAeEvent",
      :method_name => "raise_evm_event",
      :args        => [event, [target.class.name, target.id], inputs],
      :role        => 'automate',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :zone        => target.respond_to?(:my_zone) ? target.my_zone : MiqServer.my_zone
    )
  end

  def build_actions
    actions = []
    notifications = (self.options ||= {})[:notifications]
    notifications.each_key do |k|
      if k == :email
        notifications[k].to_miq_a.each do |n|
          n[:to].each do |to|
            description = "#{k.to_s.titleize} Action To: [#{to}] for Alert: #{self.description}"
            actions << MiqAction.new(
              :action_type => k.to_s,
              :options     => {:from => n[:from], :to => to},
              :name        => description,
              :description => description
            )
          end
        end
      elsif k == :snmp
        notifications[k].to_miq_a.each do |n|
          description = "#{k.to_s.titleize} Action for Alert: #{self.description}"
          action_type = "snmp_trap"
          actions << MiqAction.new(
            :action_type => action_type,
            :options     => n,
            :name        => description,
            :description => description
          )
        end
      elsif k == :evm_event
        description = "#{k.to_s.titleize} Action for Alert: #{self.description}"
        action_type = "evm_event"
        actions << MiqAction.new(
          :action_type => action_type,
          :name        => description,
          :description => description
        )
      else
        actions << k
      end
    end

    actions
  end

  def eval_expression(target, inputs = {})
    return Condition.evaluate(self, target, inputs) if miq_expression
    return true if hash_expression && hash_expression[:eval_method] == "nothing"

    raise "unable to evaluate expression: [#{miq_expression.inspect}], unknown format" unless hash_expression

    case hash_expression[:mode]
    when "internal" then return evaluate_internal(target, inputs)
    when "automate" then return evaluate_in_automate(target, inputs)
    when "script"   then return evaluate_script
    else                 raise "unable to evaluate expression: [#{hash_expression.inspect}], unknown mode"
    end
  end

  def self.rt_perf_model_details(dbs)
    dbs.inject({}) do |h, db|
      h[db] = Metric::Rollup.const_get("#{db.underscore.upcase}_REALTIME_COLS").inject({}) do |hh, c|
        hh[c.to_s] = Dictionary.gettext("#{db}Performance.#{c}")
        hh
      end
      h
    end
  end

  def self.operating_range_perf_model_details(dbs)
    dbs.inject({}) do |h, db|
      h[db] = Metric::LongTermAverages::AVG_COLS.inject({}) do |hh, c|
        hh[c.to_s] = Dictionary.gettext("#{db}Performance.#{c}")
        hh
      end
      h
    end
  end

  def self.hourly_perf_model_details(dbs)
    dbs.inject({}) do |h, db|
      perf_model = "#{db}Performance"
      h[db] = MiqExpression.model_details(perf_model, :include_model => false, :interval => "hourly").inject({}) do |hh, a|
        d, c = a
        model, col = c.split("-")
        next(hh) unless model == perf_model
        next(hh) if ["timestamp", "v_date", "v_time", "resource_name"].include?(col)
        next(hh) if col.starts_with?("abs_") && col.ends_with?("_timestamp")
        hh[col] = d
        hh
      end
      h
    end
  end

  def self.automate_expressions
    @automate_expressions ||= [
      {:name => "nothing", :description => _(" Nothing"), :db => BASE_TABLES, :options => []},
      {:name => "ems_alarm", :description => _("VMware Alarm"), :db => ["Vm", "Host", "EmsCluster"], :responds_to_events => 'AlarmStatusChangedEvent_#{hash_expression[:options][:ems_id]}_#{hash_expression[:options][:ems_alarm_mor]}',
        :options => [
          {:name => :ems_id, :description => _("Management System")},
          {:name => :ems_alarm_mor, :description => _("Alarm")}
        ]},
      {:name => "event_threshold", :description => _("Event Threshold"), :db => ["Vm"], :responds_to_events => '#{hash_expression[:options][:event_types]}',
        :options => [
          {:name => :event_types, :description => _("Event to Check"), :values => ["CloneVM_Task", "CloneVM_Task_Complete", "DrsVmPoweredOnEvent", "MarkAsTemplate_Complete", "MigrateVM_Task", "PowerOnVM_Task_Complete", "ReconfigVM_Task_Complete", "ResetVM_Task_Complete", "ShutdownGuest_Complete", "SuspendVM_Task_Complete", "UnregisterVM_Complete", "VmPoweredOffEvent", "RelocateVM_Task_Complete"]},
          {:name => :time_threshold, :description => _("How Far Back to Check"), :required => true},
          {:name => :freq_threshold, :description => _("Event Count Threshold"), :required => true, :numeric => true}
        ]},
      {:name => "event_log_threshold", :description => _("Event Log Threshold"), :db => ["Vm"], :responds_to_events  => "vm_scan_complete",
        :options => [
          {:name => :event_log_message_filter_type, :description => _("Message Filter Type"), :values => ["STARTS WITH", "ENDS WITH", "INCLUDES", "REGULAR EXPRESSION"], :required => true},
          {:name => :event_log_message_filter_value, :description => _("Message Filter"), :required => true},
          {:name => :event_log_name, :description => _("Event Log Name")},
          {:name => :event_log_level, :description => _("Event Level")},
          {:name => :event_log_event_id, :description => _("Event Id")},
          {:name => :event_log_source, :description => _("Event Source")},
          {:name => :time_threshold, :description => _("How Far Back to Check"), :required => true},
          {:name => :freq_threshold, :description => _("Event Count Threshold"), :required => true, :numeric => true}
        ]},
      {:name => "hostd_log_threshold", :description => _("Hostd Log Threshold"), :db => ["Host"], :responds_to_events => "host_scan_complete",
        :options => [
          {:name => :event_log_message_filter_type, :description => _("Message Filter Type"), :values => ["STARTS WITH", "ENDS WITH", "INCLUDES", "REGULAR EXPRESSION"], :required => true},
          {:name => :event_log_message_filter_value, :description => _("Message Filter"), :required => true},
          {:name => :event_log_level, :description => _("Message Level")},
          {:name => :event_log_source, :description => _("Message Source")},
          {:name => :time_threshold, :description => _("How Far Back to Check"), :required => true},
          {:name => :freq_threshold, :description => _("Event Count Threshold"), :required => true, :numeric => true}
        ]},
      {:name => "realtime_performance", :description => _("Real Time Performance"), :db => (dbs = ["Vm", "Host", "EmsCluster"]), :responds_to_events => '#{db.underscore}_perf_complete',
        :options => [
          {:name => :perf_column, :description => _("Performance Field"), :values => rt_perf_model_details(dbs)},
          {:name => :operator, :description => _("Operator"), :values => [">", ">=", "<", "<=", "="]},
          {:name => :value_threshold, :description => _("Value Threshold"), :required => true},
          {:name => :trend_direction, :description => _("And is Trending"), :required => true, :values => {"none" => " Don't Care", "up" => "Up", "up_more_than" => "Up More Than", "down" => "Down", "down_more_than" => "Down More Than", "not_up" => "Not Up", "not_down" => "Not Down"}},
          {:name => :trend_steepness, :description => _("Per Minute"), :required => false},
          {:name => :rt_time_threshold, :description => _("Field Meets Criteria for"), :required => true},
          {:name => :debug_trace, :description => _("Debug Tracing"), :required => true, :values => ["false", "true"]},
        ]},
      {:name => "operating_range_exceptions", :description => _("Normal Operating Range"), :db => (dbs = ["Vm"]), :responds_to_events => "vm_perf_complete",
        :options => [
          {:name => :perf_column, :description => _("Performance Field"), :values => operating_range_perf_model_details(dbs)},
          {:name => :operator, :description => _("Operator"), :values => ["Exceeded", "Fell Below"]},
          {:name => :rt_time_threshold, :description => _("Field Meets Criteria for"), :required => true}
        ]},
      {:name => "hourly_performance", :description => _("Hourly Performance"), :db => (dbs = ["EmsCluster"]), :responds_to_events => "_hourly_timer_",
        :options => [
          {:name => :perf_column, :description => _("Performance Field"), :values => hourly_perf_model_details(dbs)},
          {:name => :operator, :description => _("Operator"), :values => [">", ">=", "<", "<=", "="]},
          {:name => :value_threshold, :description => _("Value Threshold"), :required => true},
          {:name => :trend_direction, :description => _("And is Trending"), :required => true, :values => {"none" => " Don't Care", "up" => "Up", "down" => "Down", "not_up" => "Not Up", "not_down" => "Not Down"}},
          {:name => :hourly_time_threshold, :description => _("Field Meets Criteria for"), :required => true},
          {:name => :debug_trace, :description => _("Debug Tracing"), :required => true, :values => ["false", "true"]},
        ]},
      {:name => "reconfigured_hardware_value", :description => _("Hardware Reconfigured"), :db => ["Vm"], :responds_to_events => "vm_reconfigure",
        :options => [
          {:name => :hdw_attr, :description => _("Hardware Attribute"), :values => {:memory_mb => Dictionary.gettext("memory_mb", :type => "column"), :cpu_total_cores => Dictionary.gettext("cpu_total_cores", :type => "column")}},
          {:name => :operator, :description => _("Operator"), :values => ["Increased", "Decreased"]}
        ]},
      {:name => "changed_vm_value", :description => _("VM Value changed"), :db => ["Vm"], :responds_to_events => "vm_reconfigure",
        :options => [
          {:name => :hdw_attr, :description => _("VM Attribute"), :values => {
            :cpu_affinity => Dictionary.gettext("cpu_affinity", :type => "column")
          }},
          {:name => :operator, :description => _("Operator"), :values => ["Changed"]}
        ]},
      {:name => "dwh_generic", :description => _("External Prometheus Alerts"), :db => ["ContainerNode", "ExtManagementSystem"], :responds_to_events => "datawarehouse_alert",
        :options => [], :always_evaluate => true}
    ]
  end

  EVM_TYPE_TO_VIM_TYPE = {
    "Vm"         => "VirtualMachine",
    "Host"       => "HostSystem",
    "EmsCluster" => "ClusterComputeResource",
    "Storage"    => "Datastore"
  }

  # TODO: vmware specific
  def self.ems_alarms(db, ems = nil)
    ems = ExtManagementSystem.extract_objects(ems)
    raise "Unable to find Management System with id: [#{id}]"  if ems.nil?

    to     = 30
    alarms = []
    begin
      Timeout.timeout(to) { alarms = ems.get_alarms if ems.respond_to?(:get_alarms) }
    rescue Timeout::Error
      msg = "Request to retrieve alarms timed out after #{to} seconds"
      $log.warn(msg)
      raise msg
    rescue MiqException::MiqVimBrokerUnavailable
      msg = "Unable to retrieve alarms, Management System Connection Broker is currently unavailable"
      $log.warn(msg)
      raise msg
    rescue => err
      $log.warn("'#{err.message}', attempting to retrieve alarms")
      raise
    end

    alarms.inject({}) do |h, a|
      exp = a.fetch_path("info", "expression", "expression")
      next(h) unless exp
      next(h) unless exp.detect { |e| e["type"] == EVM_TYPE_TO_VIM_TYPE[db] || e["objectType"] == EVM_TYPE_TO_VIM_TYPE[db] }
      h[a["MOR"]] = a["info"]["name"]
      h
    end
  end

  def self.expression_types(db = nil)
    automate_expressions.inject({}) do |h, e|
      next(h) unless db.nil? || e[:db].nil? || e[:db].include?(db)
      h[e[:name]] = e[:description]
      h
    end
  end

  def self.expression_options(name)
    exp = expression_by_name(name)
    return nil unless exp
    exp[:options]
  end

  def self.expression_by_name(name)
    automate_expressions.find { |e| e[:name] == name }
  end

  def self.raw_events
    @raw_events ||= expression_by_name("event_threshold")[:options].find { |h| h[:name] == :event_types }[:values] +
                    %w(datawarehouse_alert)
  end

  def self.event_alertable?(event)
    raw_events.include?(event.to_s)
  end

  def self.alarm_has_alerts?(alarm_event)
    where("responds_to_events LIKE ?", "%#{alarm_event}%").count > 0
  end

  def responds_to_events_from_expression
    return nil if miq_expression || hash_expression.nil? || hash_expression[:eval_method] == "nothing"

    options = self.class.expression_by_name(hash_expression[:eval_method])
    options && substitute(options[:responds_to_events])
  end

  def substitute(str)
    eval("result = \"#{str}\"")
  end

  def evaluate_in_automate(target, inputs = {})
    target_key = target.class.name.singularize.downcase.to_sym
    inputs[target_key] = target
    [:vm, :host, :ext_management_system].each { |k| inputs[k] = target.send(target_key) if target.respond_to?(target_key) }

    aevent = inputs
    aevent[:eval_method]  = hash_expression[:eval_method]
    aevent[:alert_class]  = self.class.name.downcase
    aevent[:alert_id]     = id
    aevent[:target_class] = target.class.base_model.name.downcase
    aevent[:target_id]    = target.id

    hash_expression[:options].each { |k, v| aevent[k] = v } if hash_expression[:options]

    begin
      result = MiqAeEvent.eval_alert_expression(target, aevent)
    rescue => err
      _log.error(err.message)
      result = false
    end
    result
  end

  def evaluate_internal(target, _inputs = {})
    method = "evaluate_method_#{hash_expression[:eval_method]}"
    options = hash_expression[:options] || {}

    raise "Evaluation method '#{hash_expression[:eval_method]}' does not exist" unless self.respond_to?(method)

    send(method, target, options)
  end

  def evaluate_script
    # TODO
    true
  end

  def evaluate_method_dwh_generic(target, options)
    target.evaluate_alert(id, options)
  end

  # Evaluation methods
  #
  def evaluate_method_changed_vm_value(target, options)
    eval_options = {
      :attr     => options[:attr],
      :operator => options[:operator]
    }
    eval_options[:attr] ||= options[:hdw_attr]
    target.changed_vm_value?(eval_options)
  end

  def evaluate_method_event_threshold(target, options)
    target.event_threshold?(options)
  end

  def evaluate_method_event_log_threshold(target, options)
    eval_options = {
      :message_filter_type  => options[:event_log_message_filter_type],
      :message_filter_value => options[:event_log_message_filter_value],
      :name                 => options[:event_log_name],
      :level                => options[:event_log_level],
      :event_id             => options[:event_log_event_id],
      :source               => options[:event_log_source],
      :time_threshold       => options[:time_threshold],
      :freq_threshold       => options[:freq_threshold]
    }
    target.event_log_threshold?(eval_options)
  end

  def evaluate_method_hostd_log_threshold(target, options)
    evaluate_method_event_log_threshold(target, options)
  end

  def evaluate_method_realtime_performance(target, options)
    eval_options = {
      :interval_name   => "realtime",
      :duration        => options[:rt_time_threshold],
      :column          => options[:perf_column],
      :value           => options[:value_threshold],
      :operator        => options[:operator],
      :debug_trace     => options[:debug_trace],
      :trend_direction => options[:trend_direction],
      :slope_steepness => options[:trend_steepness]
    }
    evaluate_performance(target, eval_options)
  end

  def evaluate_method_operating_range_exceptions(target, options)
    eval_options = {
      :interval_name => "realtime",
      :duration      => options[:rt_time_threshold],
      :debug_trace   => options[:debug_trace]
    }

    # options[:perf_column] points to one of keys in vim_performance_operating_ranges's values column
    # which stores the long term average data
    # eval_options[:column] points to the column in metrics, where data are collected and to be compared
    # with the average.
    # A column name conversion is needed as follows
    eval_options[:column] =
      case options[:perf_column]
      when "max_cpu_usage_rate_average"
        "cpu_usage_rate_average"
      when "max_mem_usage_absolute_average"
        "mem_usage_absolute_average"
      else
        options[:perf_column]
      end

    case options[:operator].downcase
    when "exceeded"
      eval_options[:operator] = ">"
      typ = "high"
    when "fell below"
      eval_options[:operator] = "<"
      typ = "low"
    else
      raise "operator '#{eval_options[:operator]}' is not valid"
    end

    val_col_name = "#{options[:perf_column]}_#{typ}_over_time_period"
    unless target.respond_to?(val_col_name)
      _log.warn("Target class [#{target.class.name}] does not support operating range, skipping")
      return false
    end

    eval_options[:value] = target.send(val_col_name)
    if eval_options[:value].nil?
      _log.info("Target class [#{target.class.name}] has no data for operating range column '#{val_col_name}', skipping")
      return false
    end

    evaluate_performance(target, eval_options)
  end

  def evaluate_method_hourly_performance(target, options)
    eval_options = {
      :interval_name   => "hourly",
      :duration        => options[:hourly_time_threshold],
      :column          => options[:perf_column],
      :value           => options[:value_threshold],
      :operator        => options[:operator],
      :debug_trace     => options[:debug_trace],
      :trend_direction => options[:trend_direction]
    }
    evaluate_performance(target, eval_options)
  end

  def evaluate_performance(target, eval_options)
    unless target.respond_to?(:performances_maintains_value_for_duration?)
      _log.warn("Target class [#{target.class.name}] does not support duration based evaluation, skipping")
      return false
    end

    status = target.miq_alert_statuses.first
    if status
      since_last_eval = (Time.now.utc - status.evaluated_on)
      eval_options[:starting_on] = if (since_last_eval >= eval_options[:duration])
                                     (status.evaluated_on + 1)
                                   else
                                     (Time.now.utc - status.evaluated_on).seconds.ago.utc
                                   end
    end
    target.performances_maintains_value_for_duration?(eval_options)
  end

  def evaluate_method_reconfigured_hardware_value(target, options)
    target.reconfigured_hardware_value?(options)
  end

  def evaluate_method_ems_alarm(_target, _options)
    true
  end

  def validate
    if self.options.kind_of?(Hash) && self.options.fetch_path(:notifications, :automate)
      event_name = self.options.fetch_path(:notifications, :automate, :event_name)
      unless (event_name =~ /[^a-z0-9_]/i).nil?
        errors.add("Event Name", "must be alphanumeric characters and underscores without spaces")
        return
      end
    end

    return if miq_expression
    return if hash_expression && hash_expression[:eval_method] == "nothing"

    if hash_expression[:options].blank?
      errors.add("expression", "has no parameters")
      return
    end

    exp_type = self.class.expression_options(hash_expression[:eval_method])
    unless exp_type
      errors.add("name", "#{hash_expression[:options][:eval_method]} is invalid")
      return
    end

    exp_type.each do |fld|
      next if fld[:required] != true
      if hash_expression[:options][fld[:name]].blank?
        errors.add("field", "'#{fld[:description]}' is required")
        next
      end

      if fld[:numeric] == true && !is_numeric?(hash_expression[:options][fld[:name]])
        errors.add("field", "'#{fld[:description]}' must be a numeric")
      end
    end
  end

  def name
    description
  end

  def self.seed
    action_fixture_file = File.join(FIXTURE_DIR, "miq_alert_default_action.yml")
    if File.exist?(action_fixture_file)
      action_hash = YAML.load_file(action_fixture_file)
      action = MiqAction.new(action_hash)
    else
      action = nil
    end

    alert_fixture_file = File.join(FIXTURE_DIR, "miq_alerts.yml")
    if File.exist?(alert_fixture_file)
      alist = YAML.load_file(alert_fixture_file)

      alist.each do |alert_hash|
        guid = alert_hash["guid"] || alert_hash[:guid]
        rec = find_by(:guid => guid)
        if rec.nil?
          alert_hash[:read_only] = true
          alert = create(alert_hash)
          _log.info("Added sample Alert: #{alert.description}")
          if action
            alert.options ||= {}
            alert.options[:notifications] ||= {}
            alert.options[:notifications][action.action_type.to_sym] = action.options
            alert.save
          end
        end
      end
    end
  end

  def export_to_array
    h = attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    [self.class.to_s => h]
  end

  def export_to_yaml
    export_to_array.to_yaml
  end

  def self.import_from_hash(alert, options = {})
    raise "No Alert to Import" if alert.nil?

    status = {:class => name, :description => alert["description"], :children => []}

    a = find_by(:guid => alert["guid"])
    msg_pfx = "Importing Alert: guid=[#{alert["guid"]}] description=[#{alert["description"]}]"
    if a.nil?
      a = new(alert)
      status[:status] = :add
    else
      status[:old_description] = a.description
      a.attributes = alert
      status[:status] = :update
    end

    unless a.valid?
      status[:status]   = :conflict
      status[:messages] = a.errors.full_messages
    end

    msg = "#{msg_pfx}, Status: #{status[:status]}"
    msg += ", Messages: #{status[:messages].join(",")}" if status[:messages]
    if options[:preview] == true
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    else
      MiqPolicy.logger.info(msg)
      a.save!
    end

    return a, status
  end

  def self.import_from_yaml(fd)
    input = YAML.load(fd)
    input.collect do |e|
      _a, stat = import_from_hash(e[name])
      stat
    end
  end
end
