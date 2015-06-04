class MiqAlert < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  include UuidMixin

  serialize :expression
  serialize :options

  validates_presence_of     :description, :guid
  validates_uniqueness_of   :description, :guid

  has_many :miq_alert_statuses, :dependent => :destroy
  before_save :set_responds_to_events

  attr_accessor :reserved

  @@base_tables = %w{
    Vm
    Host
    Storage
    EmsCluster
    ExtManagementSystem
    MiqServer
  }
  cattr_accessor :base_tables

  include ReportableMixin

  acts_as_miq_set_member

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

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
    Dictionary.gettext(self.db, :type => :model)
  end

  def evaluation_description
    return "Expression (Custom)" if     self.expression.kind_of?(MiqExpression)
    return "None"                unless self.expression && self.expression.kind_of?(Hash) && self.expression.has_key?(:eval_method)

    exp = self.class.expression_by_name(self.expression[:eval_method])
    return exp ? exp[:description] : "Unknown"
  end

  # Define methods for notify_* virtual columns
  [:automate, :email, :evm_event, :snmp].each do |n|
    define_method("notify_#{n}") do
      (self.options || {}).has_key_path?(:notifications, n)
    end
  end

  def miq_actions
    []
  end
  alias actions miq_actions
  alias owning_miq_actions miq_actions

  def set_responds_to_events
    events = self.responds_to_events_from_expression
    self.responds_to_events = events unless events.nil?
  end

  def self.assigned_to_target(target, event=nil)
    # Get all assigned, enabled alerts based on target class and event
    cond = "enabled = ? AND db = ?"
    args = [true, target.class.base_model.name]
    key  = "#{target.class.base_model.name}_#{target.id}"

    unless event.nil?
      cond += " AND responds_to_events LIKE ?"
      args << "%#{event}%"
      key  += "_#{event}"
    end

    self.alert_assignments[key] ||= begin
      profiles  = MiqAlertSet.assigned_to_target(target, :find_options => {:conditions => ["mode = ?", target.class.base_model.name], :select => "id"})
      alert_ids = profiles.collect {|p| p.members(:select => "id").collect(&:id)}.flatten.uniq

      if alert_ids.empty?
        []
      else
        cond += " AND id IN (?)"
        args << alert_ids
        self.where(cond, *args).to_a
      end
    end
  end


  def self.target_needs_realtime_capture?(target)

    result = !self.assigned_to_target(target, "#{target.class.base_model.name.underscore}_perf_complete").empty?
    return result if result

    # Need to special case Host to look for alerts assigned to parent cluster
    if target.kind_of?(Host) && target.ems_cluster
      result = !self.assigned_to_target(target.ems_cluster, "#{target.ems_cluster.class.name.underscore}_perf_complete").empty?
    end

    return result
  end

  def self.evaluate_alerts(target, event, inputs={})
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end

    log_header = "MIQ(#{self.name}.evaluate_alerts) [#{event}]"
    log_target = "Target: #{target.class.name} Name: [#{target.name}], Id: [#{target.id}]"
    $log.info("#{log_header} #{log_target}")

    self.assigned_to_target(target, event).each do |a|
      next if a.postpone_evaluation?(target)
      $log.info("#{log_header} #{log_target} Queuing evaluation of Alert: [#{a.description}]")
      a.evaluate_queue(target, inputs)
    end
  end

  def self.evaluate_hourly_timer
    log_header = "MIQ(#{self.name}.evaluate_hourly_timer)"
    $log.info("#{log_header} Starting")

    # Find all active alerts that respond to _hourly_timer_ that have assignments
    # assignments = MiqAlert.assignments(:conditions => ["enabled = ? and responds_to_events like ?", true, "%#{HOURLY_TIMER_EVENT}%"])
    # TODO: Optimize to filter out sets that don't have any enabled alerts that respond to HOURLY_TIMER_EVENT
    assignments = MiqAlertSet.assignments

    zone = MiqServer.my_server.zone

    # Get list of targets from assigned profiles
    targets = []
    assignments.each do |ass|
      prof = ass[:assigned]
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
    targets.uniq.each {|t| self.evaluate_alerts(t, HOURLY_TIMER_EVENT)}

    $log.info("#{log_header} Complete")
  end

  def evaluate_queue(targets, inputs={})
    targets.to_miq_a.each do |target|
      zone = target.respond_to?(:my_zone) ? target.my_zone : MiqServer.my_zone
      MiqQueue.put_unless_exists(
        :class_name  => self.class.name,
        :instance_id => self.id,
        :method_name => "evaluate",
        :args        => [[target.class.name, target.id], inputs],
        :zone        => zone
      )
    end
  end

  def postpone_evaluation?(target)
    #TODO: Are there some alerts that we always want to evaluate?

    # If a miq alert status exists for our resource and alert, and it has not been delay_next_evaluation seconds since it was evaluated, return false so we can skip evaluation
    delay_next_evaluation = (self.options || {}).fetch_path(:notifications, :delay_next_evaluation)
    start_skipping_at = Time.now.utc - (delay_next_evaluation || 10.minutes).to_i

    statuses_not_expired = self.miq_alert_statuses.count(:conditions => ["result = ? AND resource_type = ? AND resource_id = ? AND evaluated_on > ?", true, target.class.base_class.name, target.id, start_skipping_at])
    if statuses_not_expired > 0
      $log.info("MIQ(Alert-postpone_evaluation?): Skipping re-evaluation of Alert [#{self.description}] for target: [#{target.name}] with delay_next_evaluation [#{delay_next_evaluation}]")
      return true
    else
      return false
    end
  end

  def evaluate(target, inputs={})
    if target.kind_of?(Array)
      klass, id = target
      klass = Object.const_get(klass)
      target = klass.find_by_id(id)
      raise "Unable to find object with class: [#{klass}], Id: [#{id}]" unless target
    end

    return if self.postpone_evaluation?(target)

    $log.info("MIQ(Alert-evaluate): Evaluating Alert [#{self.description}] for target: [#{target.name}]...")
    result = eval_expression(target, inputs)
    $log.info("MIQ(Alert-evaluate): Evaluating Alert [#{self.description}] for target: [#{target.name}]... Result: [#{result}]")

    # If we are alerting, invoke the alert actions, then add a status so we can limit how often to alert
    # Otherwise, destroy this alert's statuses for our target
    self.invoke_actions(target, inputs) if result
    self.add_status_post_evaluate(target, result)

    return result
  end

  def add_status_post_evaluate(target, result)
    existing = self.miq_alert_statuses.where(:resource_type => target.class.base_class.name, :resource_id => target.id).first
    status = existing.nil? ? MiqAlertStatus.new : existing
    status.result = result
    status.evaluated_on = Time.now.utc
    status.resource = target
    status.save
    self.miq_alert_statuses << status
  end

  def invoke_actions(target, inputs={})
    begin
      self.build_actions.each do |a|
        if a.kind_of?(MiqAction)
          inputs = inputs.merge(:policy => self, :event => MiqEvent.new(:name => "AlertEvent", :description => "Alert condition met"))
          a.invoke(target, inputs.merge(:result => true, :sequence => a.sequence, :synchronous => false))
        else
          next if a == :delay_next_evaluation
          method = "invoke_#{a}"
          unless self.respond_to?(method)
            $log.warn("MIQ(Alert-invoke_actions): Unknown notification type: [#{a}], skipping invocation")
            next
          end
          self.send(method, target, inputs)
        end
      end
    rescue MiqException::StopAction => err
      $log.error("MIQ(Alert-invoke) Stopping action invocation [#{err.message}]")
      return
    rescue MiqException::UnknownActionRc => err
      $log.error("MIQ(Alert-invoke) Aborting action invocation [#{err.message}]")
      raise
    rescue MiqException::PolicyPreventAction => err
      $log.info "MIQ(Alert-invoke) [#{err}]"
      raise
    end
  end

  def invoke_automate(target, inputs)
    inputs = {:miq_alert_description => self.description, :miq_alert_id => self.id, :alert_guid => self.guid}
    event  = self.options.fetch_path(:notifications, :automate, :event_name)
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

    return actions
  end

  def eval_expression(target, inputs={})
    return Condition.evaluate(self, target, inputs) if self.expression.is_a?(MiqExpression)
    return true if self.expression.kind_of?(Hash) && self.expression[:eval_method] == "nothing"

    raise "unable to evaluate expression: [#{self.expression.inspect}], unknown format" unless self.expression.kind_of?(Hash)

    case self.expression[:mode]
    when "internal" then return self.evaluate_internal(target, inputs)
    when "automate" then return self.evaluate_in_automate(target, inputs)
    when "script"   then return self.evaluate_script
    else                 raise "unable to evaluate expression: [#{self.expression.inspect}], unknown mode"
    end
  end

  def self.rt_perf_model_details(dbs)
    return dbs.inject({}) do |h,db|
      h[db] = Metric::Rollup.const_get("#{db.underscore.upcase}_REALTIME_COLS").inject({}) do |hh,c|
        hh[c.to_s] = Dictionary.gettext("#{db}Performance.#{c}")
        hh
      end
      h
    end
  end

  def self.operating_range_perf_model_details(dbs)
    dbs.inject({}) do |h,db|
      h[db] = Metric::LongTermAverages::AVG_COLS.inject({}) { |hh,c| hh[c.to_s] = Dictionary.gettext("#{db}Performance.#{c}"); hh}
      h
    end
  end

  def self.hourly_perf_model_details(dbs)
    dbs.inject({}) do |h,db|
      perf_model = "#{db}Performance"
      h[db] = MiqExpression.model_details(perf_model, :include_model => false, :interval => "hourly").inject({}) do |hh,a|
        d,c = a
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
      {:name => "nothing", :description => " Nothing", :db => @@base_tables, :options => []},
      {:name => "ems_alarm", :description => "VMware Alarm", :db => ["Vm", "Host", "EmsCluster"], :responds_to_events => 'AlarmStatusChangedEvent_#{expression[:options][:ems_id]}_#{expression[:options][:ems_alarm_mor]}',
        :options => [
          {:name => :ems_id, :description => "Management System"},
          {:name => :ems_alarm_mor, :description => "Alarm"}
        ]},
      {:name => "event_threshold", :description => "Event Threshold", :db => ["Vm"], :responds_to_events => '#{expression[:options][:event_types]}',
        :options => [
          {:name => :event_types, :description => "Event to Check", :values => ["CloneVM_Task", "CloneVM_Task_Complete", "DrsVmPoweredOnEvent", "MarkAsTemplate_Complete", "MigrateVM_Task", "PowerOnVM_Task_Complete", "ReconfigVM_Task_Complete", "ResetVM_Task_Complete", "ShutdownGuest_Complete", "SuspendVM_Task_Complete", "UnregisterVM_Complete", "VmPoweredOffEvent", "RelocateVM_Task_Complete"]},
          {:name => :time_threshold, :description => "How Far Back to Check", :required => true},
          {:name => :freq_threshold, :description => "Event Count Threshold", :required => true, :numeric => true}
        ]},
      {:name => "event_log_threshold", :description => "Event Log Threshold", :db => ["Vm"], :responds_to_events  => "vm_scan_complete",
        :options => [
          {:name => :event_log_message_filter_type, :description => "Message Filter Type", :values => ["STARTS WITH", "ENDS WITH", "INCLUDES", "REGULAR EXPRESSION"], :required => true},
          {:name => :event_log_message_filter_value, :description => "Message Filter", :required => true},
          {:name => :event_log_name, :description => "Event Log Name"},
          {:name => :event_log_level, :description => "Event Level"},
          {:name => :event_log_event_id, :description => "Event Id"},
          {:name => :event_log_source, :description => "Event Source"},
          {:name => :time_threshold, :description => "How Far Back to Check", :required => true},
          {:name => :freq_threshold, :description => "Event Count Threshold", :required => true, :numeric => true}
        ]},
      {:name => "hostd_log_threshold", :description => "Hostd Log Threshold", :db => ["Host"], :responds_to_events => "host_scan_complete",
        :options => [
          {:name => :event_log_message_filter_type, :description => "Message Filter Type", :values => ["STARTS WITH", "ENDS WITH", "INCLUDES", "REGULAR EXPRESSION"], :required => true},
          {:name => :event_log_message_filter_value, :description => "Message Filter", :required => true},
          {:name => :event_log_level, :description => "Message Level"},
          {:name => :event_log_source, :description => "Message Source"},
          {:name => :time_threshold, :description => "How Far Back to Check", :required => true},
          {:name => :freq_threshold, :description => "Event Count Threshold", :required => true, :numeric => true}
        ]},
      {:name => "realtime_performance", :description => "Real Time Performance", :db => (dbs = ["Vm", "Host", "EmsCluster"]), :responds_to_events => '#{db.underscore}_perf_complete',
        :options => [
          {:name => :perf_column, :description => "Performance Field", :values => self.rt_perf_model_details(dbs)},
          {:name => :operator, :description => "Operator", :values => [">", ">=", "<", "<=", "="]},
          {:name => :value_threshold, :description => "Value Threshold", :required => true},
          {:name => :trend_direction, :description => "And is Trending", :required => true, :values => {"none" => " Don't Care","up" => "Up","up_more_than" => "Up More Than","down" => "Down","down_more_than" => "Down More Than","not_up" => "Not Up","not_down" => "Not Down"}},
          {:name => :trend_steepness, :description => "Per Minute", :required => false},
          {:name => :rt_time_threshold, :description => "Field Meets Criteria for", :required => true},
          {:name => :debug_trace, :description => "Debug Tracing", :required => true, :values => ["false", "true"]},
        ]},
      {:name => "operating_range_exceptions", :description => "Normal Operating Range", :db => (dbs = ["Vm"]), :responds_to_events => "vm_perf_complete",
        :options => [
          {:name => :perf_column, :description => "Performance Field", :values => self.operating_range_perf_model_details(dbs)},
          {:name => :operator, :description => "Operator", :values => ["Exceeded", "Fell Below"]},
          {:name => :rt_time_threshold, :description => "Field Meets Criteria for", :required => true}
        ]},
      {:name => "hourly_performance", :description => "Hourly Performance", :db => (dbs = ["EmsCluster"]), :responds_to_events => "_hourly_timer_",
        :options => [
          {:name => :perf_column, :description => "Performance Field", :values => self.hourly_perf_model_details(dbs)},
          {:name => :operator, :description => "Operator", :values => [">", ">=", "<", "<=", "="]},
          {:name => :value_threshold, :description => "Value Threshold", :required => true},
          {:name => :trend_direction, :description => "And is Trending", :required => true, :values => {"none" => " Don't Care","up" => "Up","down" => "Down","not_up" => "Not Up","not_down" => "Not Down"}},
          {:name => :hourly_time_threshold, :description => "Field Meets Criteria for", :required => true},
          {:name => :debug_trace, :description => "Debug Tracing", :required => true, :values => ["false", "true"]},
        ]},
      {:name => "reconfigured_hardware_value", :description => "Hardware Reconfigured", :db => ["Vm"], :responds_to_events => "vm_reconfigure",
        :options => [
          {:name => :hdw_attr, :description => "Hardware Attribute", :values => {:memory_cpu => Dictionary.gettext("memory_cpu", :type => "column"), :numvcpus => Dictionary.gettext("numvcpus", :type => "column")}},
          {:name => :operator, :description => "Operator", :values => ["Increased", "Decreased"]}
        ]},
      {:name => "changed_vm_value", :description => "VM Value changed", :db => ["Vm"], :responds_to_events => "vm_reconfigure",
        :options => [
          {:name => :hdw_attr, :description => "VM Attribute", :values => {
              :cpu_affinity => Dictionary.gettext("cpu_affinity", :type => "column")
            }},
          {:name => :operator, :description => "Operator", :values => ["Changed"]}
        ]}
    ]
  end

  EVM_TYPE_TO_VIM_TYPE = {
    "Vm"         => "VirtualMachine",
    "Host"       => "HostSystem",
    "EmsCluster" => "ClusterComputeResource",
    "Storage"    => "Datastore"
  }

  #TODO: vmware specific
  def self.ems_alarms(db, ems=nil)
    ems = ExtManagementSystem.extract_objects(ems)
    raise "Unable to find Management System with id: [#{id}]"  if ems.nil?

    to     = 30
    alarms = []
    begin
      Timeout::timeout(to) { alarms = ems.get_alarms if ems.respond_to?(:get_alarms) }
    rescue TimeoutError
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

    alarms.inject({}) do |h,a|
      exp = a.fetch_path("info", "expression", "expression")
      next(h) unless exp
      next(h) unless exp.detect {|e| e["type"] == EVM_TYPE_TO_VIM_TYPE[db] || e["objectType"] == EVM_TYPE_TO_VIM_TYPE[db]}
      h[a["MOR"]] = a["info"]["name"]
      h
    end
  end

  def self.expression_types(db = nil)
    self.automate_expressions.inject({}) do |h,e|
      next(h) unless db.nil? || e[:db].nil? || e[:db].include?(db)
      h[e[:name]] = e[:description]
      h
    end
  end

  def self.expression_options(name)
    exp = self.expression_by_name(name)
    return nil unless exp
    return exp[:options]
  end

  def self.expression_by_name(name)
    self.automate_expressions.find {|e| e[:name] == name}
  end

  def self.raw_events
    @raw_events ||= expression_by_name("event_threshold")[:options].find{|h| h[:name] == :event_types}[:values]
  end

  def self.event_alertable?(event)
    self.raw_events.include?(event.to_s)
  end

  def self.alarm_has_alerts?(alarm_event)
    self.count(:conditions => ["responds_to_events LIKE ?", "%#{alarm_event}%"]) > 0
  end

  def responds_to_events_from_expression
    return nil if self.expression.nil? || self.expression.kind_of?(MiqExpression) || self.expression[:eval_method] == "nothing"

    options = self.class.expression_by_name(self.expression[:eval_method])
    return options.nil? ? nil : self.substitute(options[:responds_to_events])
  end

  def substitute(str)
    eval "result = \"#{str}\""
  end

  def evaluate_in_automate(target, inputs={})
    target_key = target.class.name.singularize.downcase.to_sym
    inputs[target_key] = target
    [:vm, :host, :ext_management_system].each { |k| inputs[k] = target.send(target_key) if target.respond_to?(target_key) }

    aevent = inputs
    aevent[:eval_method]  = self.expression[:eval_method]
    aevent[:alert_class]  = self.class.name.downcase
    aevent[:alert_id]     = self.id
    aevent[:target_class] = target.class.base_model.name.downcase
    aevent[:target_id]    = target.id

    self.expression[:options].each {|k,v| aevent[k] = v} if self.expression[:options]

    begin
      result = MiqAeEvent.eval_alert_expression(aevent)
    rescue => err
      $log.error("MIQ(alert-evaluate_in_automate) #{err.message}")
      result = false
    end
    return result
  end

  def evaluate_internal(target, inputs={})
    method = "evaluate_method_#{self.expression[:eval_method]}"
    raise "Evaluation method '#{self.expression[:eval_method]}' does not exist" unless self.respond_to?(method)

    self.send(method, target, self.expression[:options] || {})
  end

  def evaluate_script
    #TODO
    return true
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
    self.evaluate_method_event_log_threshold(target, options)
  end

  def evaluate_method_realtime_performance(target, options)
    eval_options = {
      :interval_name => "realtime",
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
      $log.warn("MIQ(alert-evaluate_method_operating_range_exceptions) Target class [#{target.class.name}] does not support operating range, skipping")
      return false
    end

    eval_options[:value] = target.send(val_col_name)
    if eval_options[:value].nil?
      $log.info("MIQ(alert-evaluate_method_operating_range_exceptions) Target class [#{target.class.name}] has no data for operating range column '#{val_col_name}', skipping")
      return false
    end

    evaluate_performance(target, eval_options)
  end

  def evaluate_method_hourly_performance(target, options)
    eval_options = {
      :interval_name => "hourly",
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
      $log.warn("MIQ(alert-evaluate_method_hourly_performance) Target class [#{target.class.name}] does not support duration based evaluation, skipping")
      return false
    end

    status = self.miq_alert_statuses.where(:resource_type => target.class.base_class.name, :resource_id => target.id).first
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

  def evaluate_method_ems_alarm(target, options)
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

    return if self.expression.is_a?(MiqExpression)
    return if self.expression.kind_of?(Hash) && self.expression[:eval_method] == "nothing"

    if self.expression[:options].blank?
      errors.add("expression", "has no parameters")
      return
    end

    exp_type = self.class.expression_options(self.expression[:eval_method])
    unless exp_type
      errors.add("name", "#{self.expression[:options][:eval_method]} is invalid")
      return
    end

    exp_type.each do |fld|
      next if fld[:required] != true
      if self.expression[:options][fld[:name]].blank?
        errors.add("field", "'#{fld[:description]}' is required")
        next
      end

      if fld[:numeric] == true && !is_numeric?(self.expression[:options][fld[:name]])
        errors.add("field", "'#{fld[:description]}' must be a numeric")
      end
    end
  end

  def name
    self.description
  end

  def self.seed
    MiqRegion.my_region.lock do
      log_prefix = "MIQ(MiqAlert.seed)"
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
          rec = self.find_by_guid(guid)
          if rec.nil?
            alert = self.create(alert_hash)
            $log.info("#{log_prefix} Added sample Alert: #{alert.description}")
            if action
              alert.options = {:notifications => {action.action_type.to_sym => action.options}}
              alert.save
            end
          end
        end
      end
    end
  end

  def export_to_array
    h = self.attributes
    ["id", "created_on", "updated_on"].each { |k| h.delete(k) }
    return [self.class.to_s => h]
  end

  def export_to_yaml
    a = export_to_array
    a.to_yaml
  end

  def self.import_from_hash(alert, options={})
    raise "No Alert to Import" if alert.nil?

    status = {:class => self.name, :description => alert["description"], :children => []}

    a = self.find_by_guid(alert["guid"])
    msg_pfx = "Importing Alert: guid=[#{alert["guid"]}] description=[#{alert["description"]}]"
    if a.nil?
      a = self.new(alert)
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
    unless options[:preview] == true
      MiqPolicy.logger.info(msg)
      a.save!
    else
      MiqPolicy.logger.info("[PREVIEW] #{msg}")
    end

    return a, status
  end

  def self.import_from_yaml(fd)
    stats = []

    input = YAML.load(fd)
    input.each { |e|
      _a, stat = import_from_hash(e[self.name])
      stats.push(stat)
    }

    return stats
  end
end
