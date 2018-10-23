class MiqSchedule < ApplicationRecord
  include DeprecationMixin
  deprecate_attribute :towhat, :resource_type

  validates :name, :uniqueness => {:scope => [:userid, :resource_type]}
  validates :name, :description, :resource_type, :run_at, :presence => true
  validate  :validate_run_at, :validate_file_depot

  before_save :set_start_time_and_prod_default

  virtual_column :v_interval_unit, :type => :string
  virtual_column :v_zone_name,     :type => :string, :uses => :zone
  virtual_column :next_run_on,     :type => :datetime

  belongs_to :file_depot
  belongs_to :miq_search
  belongs_to :resource, :polymorphic => true
  belongs_to :zone

  scope :in_zone, lambda { |zone_name|
    includes(:zone).where("zones.name" => zone_name)
  }

  scope :updated_since, lambda { |time|
    where("updated_at > ?", time)
  }

  scope :filter_matches_with,      ->(exp)           { where(:filter => exp) }
  scope :with_prod_default_not_in, ->(prod)          { where.not(:prod_default => prod).or(where(:prod_default => nil)) }
  scope :without_adhoc,            ->                { where(:adhoc => nil) }
  scope :with_towhat,              ->(resource_type) { where(:resource_type => resource_type) }
  scope :with_userid,              ->(userid)        { where(:userid => userid) }

  serialize :sched_action
  serialize :filter
  serialize :run_at

  SYSTEM_SCHEDULE_CLASSES = %w(MiqReport MiqAlert MiqWidget).freeze
  VALID_INTERVAL_UNITS = %w(minutely hourly daily weekly monthly once).freeze
  ALLOWED_CLASS_METHOD_ACTIONS = %w(db_backup db_gc automation_request).freeze

  default_value_for :userid,  "system"
  default_value_for :enabled, true
  default_value_for(:zone_id) { MiqServer.my_server.zone_id }

  def set_start_time_and_prod_default
    run_at # Internally this will correct :start_time to UTC
    self.prod_default = "system" if SYSTEM_SCHEDULE_CLASSES.include?(resource_type.to_s)
  end

  def run_at
    val = self[:run_at]
    if val.kind_of?(Hash)
      st = val[:start_time]
      if st && String === st
        val[:start_time] = st.to_time(:utc).utc
      end
    end
    val
  end

  def self.queue_scheduled_work(id, _rufus_job_id, at, _params)
    # puts "rufus_job_id: #{rufus_job_id}"
    # puts "previous at: #{params[:previous_at]}, #{Time.at(params[:previous_at])}" if params[:previous_at]
    # puts "at:          #{at}, #{Time.at(at)}"
    # puts "now:         #{Time.now.to_f}, #{Time.now}"
    # puts "params: #{params.inspect}"

    sched = find_by(:id => id)
    unless sched
      _log.warn("unable to find schedule with id: [#{id}], skipping")
      return
    end

    method = sched.sched_action[:method] rescue nil
    _log.info("Queueing start of schedule id: [#{id}] [#{sched.name}] [#{sched.resource_type}] [#{method}]")

    action = "action_" + method

    if sched.respond_to?(action)
      msg = MiqQueue.submit_job(
        :class_name  => name,
        :instance_id => sched.id,
        :method_name => "invoke_actions",
        :args        => [action, at],
        :msg_timeout => 1200
      )

      _log.info("Queueing start of schedule id: [#{id}] [#{sched.name}] [#{sched.resource_type}] [#{method}]...complete")
      msg
    elsif sched.resource.respond_to?(method)
      sched.resource.send(method, *sched.sched_action[:args])
      sched.update_attributes(:last_run_on => Time.now.utc)
    else
      _log.warn("[#{sched.name}] no such action: [#{method}], aborting schedule")
    end
  end

  def invoke_actions(action, at)
    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    if get_filter.nil? && sched_action.kind_of?(Hash) && !ALLOWED_CLASS_METHOD_ACTIONS.include?(sched_action[:method])
      _log.warn("[#{name}] Schedule has no filter, skipping invocation")
      return
    end

    targets = get_targets
    _log.warn("[#{name}] No targets match filter [#{filter.to_human}]") if targets.empty? && !filter.nil?
    targets.each do |obj|
      _log.info("[#{name}] invoking action: [#{sched_action[:method]}] for target: [#{obj.name}]")
      begin
        send(action, obj, at)
      rescue => err
        _log.error("[#{name}] Attempting to run action [#{action}] on target [#{obj.name}], #{err}")
        # _log.log_backtrace(err)
      end
    end
    update_attribute(:last_run_on, Time.now.utc)
    self
  end

  def target_ids
    # Let RBAC evaluate the filter's MiqExpression, and return the first value (the target ids)
    my_filter = get_filter
    return [] if my_filter.nil?
    Rbac.filtered(resource_type, :filter => my_filter).pluck(:id)
  end

  def get_targets
    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    return [Object.const_get(resource_type)] if sched_action.kind_of?(Hash) && ALLOWED_CLASS_METHOD_ACTIONS.include?(sched_action[:method])

    my_filter = get_filter
    if my_filter.nil?
      _log.warn("[#{name}] Filter is empty")
      return []
    end

    Rbac.filtered(resource_type, :filter => my_filter)
  end

  def get_filter
    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    miq_search.nil? ? filter : miq_search.filter
  end

  def next_run_on
    return nil if enabled == false

    # calculate what the next run on time should be
    if run_at[:interval][:unit].downcase != "once"
      time = next_interval_time
    else
      time = (last_run_on && (last_run_on > run_at[:start_time])) ? nil : run_at[:start_time]
    end
    time.try(:utc)
  end

  def run_at_to_human(timezone)
    start_time = run_at[:start_time].in_time_zone(timezone)
    start_time = start_time.strftime("%a %b %d %H:%M:%S %Z %Y")
    if run_at[:interval][:unit].downcase == "once"
      return _("Run %{interval} on %{start_time}") % {:interval => run_at[:interval][:unit], :start_time => start_time}
    else
      if run_at[:interval][:value].to_i == 1
        return _("Run %{interval} starting on %{start_time}") % {:interval   => run_at[:interval][:unit],
                                                                 :start_time => start_time}
      else
        case run_at[:interval][:unit]
        when "minutely"
          unit = _("minutes")
        when "hourly"
          unit = _("hours")
        when "daily"
          unit = _("days")
        when "weekly"
          unit = _("weeks")
        when "monthly"
          unit = _("months")
        end
        return _("Run %{interval} every %{value} %{unit} starting on %{start_time}") %
                 {:interval   => run_at[:interval][:unit],
                  :value      => run_at[:interval][:value],
                  :unit       => unit,
                  :start_time => start_time}
      end
    end
  end

  def action_test(obj, _at)
    _log.info("[#{name}] Action has been run for target: [#{obj.name}]")
    puts("[#{Time.now}] MIQ(Schedule.action-test) [#{name}] Action has been run for target: [#{obj.name}]")
  end

  def action_vm_scan(obj, _at)
    sched_action[:options] ||= {}
    obj.scan_queue(userid, sched_action[:options])
    _log.info("Action [#{name}] has been run for target: [#{obj.name}]")
  end

  def action_scan(obj, _at)
    sched_action[:options] ||= {}
    obj.scan(userid)
    _log.info("Action [#{name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def action_run_report(obj, at)
    sched_action[:options] ||= {}
    sched_action[:options][:userid] = userid
    opts = sched_action[:options]
    res_opts = {:at => at, :source => 'Scheduled'}
    _log.info("Action [#{name}] Starting queue_report_result for report: [#{obj.name}], with options: [#{opts.inspect}], res_opts: [#{res_opts.inspect}]")
    obj.queue_report_result(opts, res_opts)
    _log.info("Action [#{name}] Finished queue_report_result for report: [#{obj.name}]")
  end

  def action_generate_widget(obj, _at)
    obj.queue_generate_content
    _log.info("Action [#{name}] has been run for target type: [#{obj.class}] with name: [#{obj.title}]")
  end

  def action_check_compliance(obj, _at)
    unless obj.respond_to?(:check_compliance_queue)
      _log.warn("Action [#{name}] is not supported for target type: [#{obj.class}] with name: [#{obj.name}], skipping")
      return
    end
    obj.check_compliance_queue
    _log.info("Action [#{name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def action_automation_request(_klass, _at)
    parameters = filter[:parameters]
    user = User.find_by_userid(userid)
    AutomationRequest.create_from_scheduled_task(user, filter[:uri_parts], parameters)
  end

  def action_db_backup(klass, _at)
    self.sched_action ||= {}
    self.sched_action[:options] ||= {}
    self.sched_action[:options][:userid] = userid
    opts = self.sched_action[:options]
    opts[:file_depot_id]   = file_depot.id
    opts[:miq_schedule_id] = id
    queue_opts = {:class_name  => klass.name, :method_name => "backup", :args => [opts], :role => "database_operations",
                  :msg_timeout => ::Settings.task.active_task_timeout.to_i_with_method}
    task_opts  = {:action => "Database backup", :userid => self.sched_action[:options][:userid]}
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def action_db_gc(klass, _at)
    self.sched_action ||= {}
    self.sched_action[:options] ||= {}
    self.sched_action[:options][:userid] = userid
    opts = self.sched_action[:options]
    queue_opts = {:class_name => klass.name, :method_name => "gc", :args => [opts], :role => "database_operations"}
    task_opts  = {:action => "Database GC", :userid => self.sched_action[:options][:userid]}
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def run_automation_request
    action_automation_request(AutomationRequest, nil)
  end

  def run_adhoc_db_backup
    action_db_backup(DatabaseBackup, nil)
  end

  def self.run_adhoc_db_gc(options)
    # options can include:
    # :userid       "admin"
    # :aggressive   true  (if provided and true, a full GC will be done)

    userid = options.delete(:userid)
    raise _("No userid provided!") unless userid

    sch = new(:userid => userid, :sched_action => {:options => options})
    sch.action_db_gc(DatabaseBackup, nil)
    # Don't save the schedule since we don't have CRUD for DB GC schedules yet
  end

  def action_evaluate_alert(obj, _at)
    MiqAlert.evaluate_queue(obj)
    _log.info("Action [#{name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def rufus_schedule_opts
    message = last_run_on ? "schedule updated" : "scheduled"

    options = {}
    case run_at[:interval][:unit].downcase
    when "once"
      # Don't run onetime schedule again unless the start_time was updated to a later time
      unless last_run_on && (last_run_on > run_at[:start_time])
        time = run_at[:start_time].getlocal
        _log.info("Schedule [#{name}] #{message} to run at #{time}")
        options = {:method => :schedule_at, :interval => time, :schedule_id => id, :discard_past => true, :tags => tag}
      end
    when "monthly"
      time = next_interval_time
      _log.info("Schedule [#{name}] #{message} to run at #{time} every #{run_at[:interval][:value]} months")
      options = {:method => :schedule_at, :months => run_at[:interval][:value].to_i, :schedule_id => id, :discard_past => true, :interval => time, :tags => tag}
    else
      time = next_interval_time
      int = interval
      _log.info("Schedule [#{name}] #{message} to run at #{time} with interval #{int}")
      options = {:method => :schedule_every, :interval => int, :schedule_id => id, :discard_past => true, :first_at => time, :tags => tag}
    end
    options
  end

  def tag
    "miq_schedules_#{id}"
  end

  def validate_run_at
    errors.add(:run_at, "run_at is missing, run_at: [#{run_at.inspect}]") unless run_at
    unless run_at.nil?
      errors.add(:run_at, "run_at is missing :start_time, run_at: [#{run_at.inspect}]") unless run_at[:start_time]
      errors.add(:run_at, "run_at is missing :interval, run_at: [#{run_at.inspect}]") unless run_at[:interval]
      unless run_at[:interval].nil?
        errors.add(:run_at, "run_at is missing :unit, run_at: [#{run_at.inspect}]") unless run_at[:interval][:unit]
        errors.add(:run_at, "run_at is missing :value, run_at: [#{run_at.inspect}]") if run_at[:interval][:unit].to_s.downcase != "once" && run_at[:interval][:value].nil?
        errors.add(:run_at, "run_at interval: [#{run_at[:interval][:unit]}] is not a valid interval") unless VALID_INTERVAL_UNITS.include?(run_at[:interval][:unit])
      end
    end
  end

  def validate_file_depot  # TODO: Do we need this if the validations are on the FileDepot classes?
    if self.sched_action.kind_of?(Hash) && self.sched_action[:method] == "db_backup" && file_depot
      errors.add(:file_depot, "is missing credentials") if !file_depot.uri.to_s.starts_with?("nfs") && file_depot.missing_credentials?
      errors.add(:file_depot, "is missing uri") if file_depot.uri.blank?
    end
  end

  def verify_file_depot(params)  # TODO: This logic belongs in the UI, not sure where
    depot_class                = FileDepot.supported_protocols[params[:uri_prefix]]
    depot                      = file_depot.class.name == depot_class ? file_depot : build_file_depot(:type => depot_class)
    depot.name                 = params[:name]
    uri                        = params[:uri]
    api_port                   = params[:swift_api_port]
    depot.aws_region           = params[:aws_region]
    depot.openstack_region     = params[:openstack_region]
    depot.keystone_api_version = params[:keystone_api_version]
    depot.v3_domain_ident      = params[:v3_domain_ident]
    depot.security_protocol    = params[:security_protocol]
    depot.uri                  = api_port.blank? ? uri : depot.merged_uri(URI(uri), api_port)
    if params[:save]
      file_depot.save!
      file_depot.update_authentication(:default => {:userid => params[:username], :password => params[:password]}) if (params[:username] || params[:password]) && depot.class.requires_credentials?
    elsif depot.class.requires_credentials?
      depot.verify_credentials(nil, params)
    end
  end

  def next_interval_time
    unless self.valid? || errors[:run_at].blank?
      _log.warn("Invalid schedule [#{id}] [#{name}]: #{errors[:run_at].to_miq_a.join(", ")}")
      return nil
    end

    timezone = run_at[:tz]
    timezone ||= 'UTC'
    sch_start_time = run_at[:start_time].in_time_zone(timezone)

    _log.info("sch_start_time: #{sch_start_time}")

    now = Time.now.in_time_zone(timezone)
    seconds_since_start =  now - sch_start_time

    if seconds_since_start < 0
      # Use the start time if it's in the future
      next_time = sch_start_time
    else
      interval_value = run_at.fetch_path(:interval, :value).to_i
      return nil if interval_value == 0

      meth = rails_interval
      if meth.nil?
        raise _("Schedule: [%{id}] [%{name}], cannot calculate next run with past start_time using: %{path}") %
                {:id => id, :name => name, :path => run_at.fetch_path(:interval, :unit)}
      end

      if meth == :months
        # use the scheduled start_time, adding x.months, until it's in the future
        # Note: months are different since there are varying number of days in a month
        next_time = sch_start_time
        interval_value = run_at.fetch_path(:interval, :value).to_i
        meth = rails_interval
        until now < (next_time += interval_value.send(meth))
        end
      else
        # Performance: Determine the number of x.days, x.minutes, etc. have elapsed since the
        # scheduled start_time and jump there instead of creating thousands of time objects
        # until we've found the first future run time
        missed_intervals = (seconds_since_start / interval_value.send(meth)).to_i
        while now > (sch_start_time + ((interval_value * missed_intervals).send(meth)))
          missed_intervals += 1
        end

        next_time = sch_start_time + ((interval_value * missed_intervals).send(meth))
        next_time += interval_value.send(meth) if next_time < now && interval_value
      end
    end

    _log.info("next_time: #{next_time}")
    next_time
  end

  def rails_interval
    case run_at.fetch_path(:interval, :unit).to_s.downcase
    when "minutely" then :minutes
    when "hourly" then   :hours
    when "daily" then    :days
    when "weekly" then   :weeks
    when "monthly" then  :months
    when "once" then     nil
    end
  end

  def interval
    unless self.valid? || errors[:run_at].blank?
      _log.warn("Invalid schedule [#{id}] [#{name}]: #{errors[:run_at].to_miq_a.join(", ")}")
      return nil
    end

    interval_value = run_at[:interval][:value].to_i
    meth = rails_interval

    meth && interval_value.send(meth)
  end

  def self.preload_schedules
    _log.info("Preloading sample schedules...")
    fixture_file = File.join(FIXTURE_DIR, "miq_schedules.yml")
    slist = YAML.load_file(fixture_file) if File.exist?(fixture_file)

    slist.each do |sched|
      rec = find_by(:name => sched[:attributes][:name])
      if rec
        rec.update_attributes(sched[:attributes])
      else
        create(sched[:attributes])
      end
    end
    _log.info("Preloading sample schedules... Done")
  end

  def v_interval_unit
    if run_at[:interval] && run_at[:interval][:unit]
      return run_at[:interval][:unit]
    else
      return nil
    end
  end

  def v_zone_name
    return "" if zone.nil?
    zone.name
  end

  def self.display_name(number = 1)
    n_('Schedule', 'Schedules', number)
  end
end # class MiqSchedule
