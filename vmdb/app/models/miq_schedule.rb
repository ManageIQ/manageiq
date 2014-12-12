class MiqSchedule < ActiveRecord::Base
  validates_uniqueness_of :name, :scope => [:userid, :towhat]
  validates_presence_of   :name, :description, :towhat, :run_at
  validate                :validate_run_at, :validate_file_depot
  has_one                 :file_depot, :as => :resource, :dependent => :destroy

  include ReportableMixin

  before_save :set_start_time_and_prod_default

  virtual_column :v_interval_unit, :type => :string
  virtual_column :v_zone_name,     :type => :string, :uses => :zone
  virtual_column :next_run_on,     :type => :datetime

  belongs_to  :zone
  belongs_to  :miq_search

  scope :in_zone, lambda { |zone_name|
    { :include => :zone, :conditions => ["zones.name = ?", zone_name] }
  }
  scope :updated_since, lambda { |time|
    { :conditions => ["updated_at > ?", time] }
  }

  serialize :sched_action
  serialize :filter
  serialize :run_at

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")
  SYSTEM_SCHEDULE_CLASSES = ["MiqReport", "MiqAlert", "MiqWidget"]
  VALID_INTERVAL_UNITS = ['minutely', 'hourly', 'daily', 'weekly', 'monthly', 'once']
  ALLOWED_CLASS_METHOD_ACTIONS = ["db_backup", "db_gc"]

  default_value_for :userid,  "system"
  default_value_for :enabled, true
  default_value_for(:zone_id) { MiqServer.my_server.zone_id }

  def set_start_time_and_prod_default
    self.run_at # Internally this will correct :start_time to UTC
    self.prod_default = "system" if SYSTEM_SCHEDULE_CLASSES.include?(self.towhat.to_s)
  end

  def run_at
    val = read_attribute(:run_at)
    if val.kind_of?(Hash)
      st = val[:start_time]
      val[:start_time] = st.to_time.utc if st
    end
    return val
  end

  def self.queue_scheduled_work(id, rufus_job_id, at, params)
    # puts "rufus_job_id: #{rufus_job_id}"
    # puts "previous at: #{params[:previous_at]}, #{Time.at(params[:previous_at])}" if params[:previous_at]
    # puts "at:          #{at}, #{Time.at(at)}"
    # puts "now:         #{Time.now.to_f}, #{Time.now}"
    # puts "params: #{params.inspect}"

    sched = self.find_by_id(id)
    unless sched
      $log.warn("MIQ(Schedule.queue_scheduled_work) unable to find schedule with id: [#{id}], skipping")
      return
    end

    method = sched.sched_action[:method] rescue nil
    $log.info("MIQ(Schedule.queue_scheduled_work) Queueing start of schedule id: [#{id}] [#{sched.name}] [#{sched.towhat}] [#{method}]")

    action = "action_" + method
    unless sched.respond_to?(action)
      $log.warn("MIQ(Schedule.queue_scheduled_work) [#{sched.name}] no such action: [#{method}], aborting schedule")
      return
    end

    msg = MiqQueue.put(
      :class_name  => self.name,
      :instance_id => sched.id,
      :method_name => "invoke_actions",
      :args        => [action, at],
      :msg_timeout => 1200
    )

    $log.info("MIQ(Schedule.queue_scheduled_work) Queueing start of schedule id: [#{id}] [#{sched.name}] [#{sched.towhat}] [#{method}]...complete")
    msg
  end

  def invoke_actions(action, at)
    log_prefix = "MIQ(Schedule.invoke_actions) [#{self.name}]"

    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    if self.get_filter.nil? && self.sched_action.kind_of?(Hash) && !ALLOWED_CLASS_METHOD_ACTIONS.include?(self.sched_action[:method])
      $log.warn("#{log_prefix} Schedule has no filter, skipping invocation")
      return
    end

    targets = self.get_targets
    $log.warn("#{log_prefix} No targets match filter [#{self.filter.to_human}]") if (targets.length == 0) && (!self.filter.nil?)
    targets.each do |obj|
      $log.info("#{log_prefix} invoking action: [#{self.sched_action[:method]}] for target: [#{obj.name}]")
      begin
        self.send(action, obj, at)
      rescue => err
        $log.error("#{log_prefix} Attempting to run action [#{action}] on target [#{obj.name}], #{err}")
        # $log.log_backtrace(err)
      end
    end
    self.update_attribute(:last_run_on, Time.now.utc)
    self
  end

  def target_ids
    # Let RBAC evaluate the filter's MiqExpression, and return the first value (the target ids)
    my_filter = self.get_filter
    return [] if my_filter.nil?
    Rbac.search(:class => self.towhat, :filter => my_filter).first
  end

  def get_targets
    log_prefix = "MIQ(Schedule.get_targets) [#{self.name}]"
    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    return [Object.const_get(self.towhat)] if self.sched_action.kind_of?(Hash) && ALLOWED_CLASS_METHOD_ACTIONS.include?(self.sched_action[:method])

    my_filter = self.get_filter
    if my_filter.nil?
      $log.warn("#{log_prefix} Filter is empty")
      return []
    end

    targets, attrs = Rbac.search(:class => self.towhat, :filter => my_filter, :results_format => :objects)
    targets
  end

  def get_filter
    # TODO: Add support to invoke_actions, get_targets, and get_filter to call class methods in addition to the normal instance methods
    self.miq_search.nil? ? self.filter : self.miq_search.filter
  end

  def next_run_on
    return nil if self.enabled == false

    # calculate what the next run on time should be
    if self.run_at[:interval][:unit].downcase != "once"
      time = self.next_interval_time
    else
      time = (self.last_run_on && (self.last_run_on > self.run_at[:start_time])) ? nil : self.run_at[:start_time]
    end
    return time.nil? ? nil : time.utc
  end

  def run_at_to_human(timezone)
    start_time = self.run_at[:start_time].in_time_zone(timezone)
    start_time = start_time.strftime("%a %b %d %H:%M:%S %Z %Y")
    if self.run_at[:interval][:unit].downcase == "once"
      return "Run #{self.run_at[:interval][:unit]} on #{start_time}"
    else
      if self.run_at[:interval][:value].to_i == 1
        return "Run #{self.run_at[:interval][:unit]} starting on #{start_time}"
      else
        case self.run_at[:interval][:unit]
        when "minutely"
          unit = "minutes"
        when "hourly"
          unit = "hours"
        when "daily"
          unit = "days"
        when "weekly"
          unit = "weeks"
        when "monthly"
          unit = "months"
        end
        return "Run #{self.run_at[:interval][:unit]} every #{self.run_at[:interval][:value]} #{unit} starting on #{start_time}"
      end
    end
  end

  def action_test(obj, at)
    $log.info("MIQ(Schedule.action-test) [#{self.name}] Action has been run for target: [#{obj.name}]")
    puts("[#{Time.now}] MIQ(Schedule.action-test) [#{self.name}] Action has been run for target: [#{obj.name}]")
  end

  def action_vm_scan(obj, at)
    self.sched_action[:options] ||= {}
    obj.scan_queue(self.userid, self.sched_action[:options])
    $log.info("MIQ(Schedule.action_vm_scan) Action [#{self.name}] has been run for target: [#{obj.name}]")
    # puts("[#{Time.now}] MIQ(Schedule.action_vm_scan) Action [#{self.name}] has been run for target: [#{obj.name}]")
  end

  def action_scan(obj, at)
    self.sched_action[:options] ||= {}
    obj.scan
    $log.info("MIQ(Schedule.action_scan) Action [#{self.name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def action_run_report(obj, at)
    self.sched_action[:options] ||= {}
    self.sched_action[:options][:userid] = self.userid
    opts = self.sched_action[:options]
    res_opts = {:at => at, :source => 'Scheduled'}
    $log.info("MIQ(Schedule.action_run_report) Action [#{self.name}] Starting queue_report_result for report: [#{obj.name}], with options: [#{opts.inspect}], res_opts: [#{res_opts.inspect}]")
    obj.queue_report_result(opts, res_opts)
    $log.info("MIQ(Schedule.action_run_report) Action [#{self.name}] Finished queue_report_result for report: [#{obj.name}]")
  end

  def action_generate_widget(obj, at)
    obj.queue_generate_content
    $log.info("MIQ(Schedule.action_generate_widget) Action [#{self.name}] has been run for target type: [#{obj.class}] with name: [#{obj.title}]")
  end

  def action_check_compliance(obj, at)
    unless obj.respond_to?(:check_compliance_queue)
      $log.warn("MIQ(Schedule.action_check_compliance) Action [#{self.name}] is not supported for target type: [#{obj.class}] with name: [#{obj.name}], skipping")
      return
    end
    obj.check_compliance_queue
    $log.info("MIQ(Schedule.action_check_compliance) Action [#{self.name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def action_db_backup(klass, at)
    self.sched_action ||= {}
    self.sched_action[:options] ||= {}
    self.sched_action[:options][:userid] = self.userid
    opts = self.sched_action[:options]
    opts[:file_depot_id]   = self.file_depot.id
    opts[:miq_schedule_id] = self.id
    queue_opts = { :class_name => klass.name, :method_name => "backup", :msg_timeout => 3600, :args => [opts], :role => "database_operations" }
    task_opts  = { :action => "Database backup", :userid => self.sched_action[:options][:userid]}
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def action_db_gc(klass, at)
    self.sched_action ||= {}
    self.sched_action[:options] ||= {}
    self.sched_action[:options][:userid] = self.userid
    opts = self.sched_action[:options]
    queue_opts = { :class_name => klass.name, :method_name => "gc", :args => [opts], :role => "database_operations" }
    task_opts  = { :action => "Database GC", :userid => self.sched_action[:options][:userid]}
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def run_adhoc_db_backup
    self.action_db_backup(DatabaseBackup, nil)
  end

  def self.run_adhoc_db_gc(options)
    # options can include:
    # :userid       "admin"
    # :aggressive   true  (if provided and true, a full GC will be done)

    userid = options.delete(:userid)
    raise "No userid provided!" unless userid

    sch = self.new(:userid => userid, :sched_action => { :options => options } )
    sch.action_db_gc(DatabaseBackup, nil)
    # Don't save the schedule since we don't have CRUD for DB GC schedules yet
  end

  def action_evaluate_alert(obj, at)
    MiqAlert.evaluate_queue(obj)
    $log.info("MIQ(Schedule.action_evaluate_alert) Action [#{self.name}] has been run for target type: [#{obj.class}] with name: [#{obj.name}]")
  end

  def rufus_schedule_opts
    message = self.last_run_on ? "schedule updated" : "scheduled"

    options = {}
    case self.run_at[:interval][:unit].downcase
    when "once"
      # Don't run onetime schedule again unless the start_time was updated to a later time
      unless self.last_run_on && (self.last_run_on > self.run_at[:start_time])
        time = self.run_at[:start_time].getlocal
        $log.info("MIQ(Schedule.rufus_schedule_opts) Schedule [#{self.name}] #{message} to run at #{time}")
        options = { :method => :schedule_at, :interval => time, :schedule_id => self.id, :discard_past => true, :tags => self.tag }
      end
    when "monthly"
      time = self.next_interval_time
      $log.info("MIQ(Schedule.rufus_schedule_opts) Schedule [#{self.name}] #{message} to run at #{time} every #{self.run_at[:interval][:value]} months")
      options = { :method => :schedule_at, :months => self.run_at[:interval][:value].to_i, :schedule_id => self.id, :discard_past => true, :interval => time, :tags => self.tag }
    else
      time = self.next_interval_time
      int = self.interval
      $log.info("MIQ(Schedule.rufus_schedule_opts) Schedule [#{self.name}] #{message} to run at #{time} with interval #{int}")
      options = { :method => :schedule_every, :interval => int, :schedule_id => self.id, :discard_past => true, :first_at => time, :tags => self.tag }
    end
    return options
  end

  def tag
    "miq_schedules_#{self.id}"
  end

  def validate_run_at
    errors.add(:run_at, "run_at is missing, run_at: [#{self.run_at.inspect}]") unless self.run_at
    unless self.run_at.nil?
      errors.add(:run_at, "run_at is missing :start_time, run_at: [#{self.run_at.inspect}]") unless self.run_at[:start_time]
      errors.add(:run_at, "run_at is missing :interval, run_at: [#{self.run_at.inspect}]") unless self.run_at[:interval]
      unless self.run_at[:interval].nil?
        errors.add(:run_at, "run_at is missing :unit, run_at: [#{self.run_at.inspect}]") unless self.run_at[:interval][:unit]
        errors.add(:run_at, "run_at is missing :value, run_at: [#{self.run_at.inspect}]") if self.run_at[:interval][:unit].to_s.downcase != "once" && self.run_at[:interval][:value].nil?
        errors.add(:run_at, "run_at interval: [#{self.run_at[:interval][:unit]}] is not a valid interval") unless VALID_INTERVAL_UNITS.include?(self.run_at[:interval][:unit])
      end
    end
  end

  def validate_file_depot
    if self.sched_action.kind_of?(Hash) && self.sched_action[:method] == "db_backup" && self.file_depot
      errors.add(:file_depot, "is missing credentials") if !file_depot.uri.to_s.starts_with?("nfs") && file_depot.authentication_invalid?
      errors.add(:file_depot, "is missing uri") if file_depot.uri.blank?
    end
  end

  def self.verify_depot_hash(hsh)
    prefix      = hsh[:uri].split("://").first
    depot_class = Object.const_get(FileDepot.supported_protocols[prefix])
    return true unless depot_class.requires_credentials?

    begin
      depot_class.validate_settings(hsh)
    rescue => err
      $log.error("Miq(Schedule.verify_depot_hash) #{err.message}.")
      false
    end
  end

  def depot_hash=(hsh = {})
    hsh            ||= {}
    depot            = self.file_depot(:include => :authentications) || self.build_file_depot
    depot.depot_hash = hsh
  end

  def depot_hash
    depot        = self.file_depot(:include => :authentications)
    depot_hash   = depot.depot_hash if depot
    depot_hash ||= {}
  end

  def next_interval_time
    unless self.valid? || self.errors.on(:run_at).empty?
      $log.warn("Miq(Schedule.next_interval_time) Invalid schedule [#{self.id}] [#{self.name}]: #{self.errors.on(:run_at).to_miq_a.join(", ")}")
      return nil
    end

    timezone = self.run_at[:tz]
    timezone ||= 'UTC'
    sch_start_time = self.run_at[:start_time].in_time_zone(timezone)

    $log.info("MIQ(Schedule.next_interval_time) sch_start_time: #{sch_start_time}")

    now = Time.now.in_time_zone(timezone)
    seconds_since_start =  now - sch_start_time

    if seconds_since_start < 0
      # Use the start time if it's in the future
      next_time = sch_start_time
    else
      interval_value = self.run_at.fetch_path(:interval, :value).to_i
      return nil if interval_value == 0

      meth = self.rails_interval
      raise "Schedule: [#{self.id}] [#{self.name}], cannot calculate next run with past start_time using: #{self.run_at.fetch_path(:interval, :unit)}" if meth.nil?

      if meth == :months
        # use the scheduled start_time, adding x.months, until it's in the future
        # Note: months are different since there are varying number of days in a month
        next_time = sch_start_time
        interval_value = self.run_at.fetch_path(:interval, :value).to_i
        meth = self.rails_interval
        until now < (next_time = next_time + interval_value.send(meth) )
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

    $log.info("MIQ(Schedule.next_interval_time) next_time: #{next_time}")
    next_time
  end

  def rails_interval
    case self.run_at.fetch_path(:interval, :unit).to_s.downcase
    when "minutely"; :minutes
    when "hourly";   :hours
    when "daily";    :days
    when "weekly";   :weeks
    when "monthly";  :months
    when "once";     nil
    else;            nil
    end
  end

  def interval
    unless self.valid? || self.errors.on(:run_at).empty?
      $log.warn("Miq(Schedule.interval) Invalid schedule [#{self.id}] [#{self.name}]: #{self.errors.on(:run_at).to_miq_a.join(", ")}")
      return nil
    end

    interval_value = self.run_at[:interval][:value].to_i
    meth = self.rails_interval

    return meth.nil? ? nil : interval_value.send(meth)
  end

  def self.preload_schedules
    $log.info("MIQ(scheule-preload_schedules) Preloading sample schedules...")
    fixture_file = File.join(FIXTURE_DIR, "miq_schedules.yml")
    slist = YAML.load_file(fixture_file) if File.exist?(fixture_file)

    slist.each do |sched|
      rec = self.find_by_name(sched[:attributes][:name])
      unless rec
        self.create(sched[:attributes])
      else
        rec.update_attributes(sched[:attributes])
      end
    end
    $log.info("MIQ(scheule-preload_schedules) Preloading sample schedules... Done")
  end

  def v_interval_unit
    if self.run_at[:interval] && self.run_at[:interval][:unit]
      return self.run_at[:interval][:unit]
    else
      return nil
    end
  end

  def v_zone_name
    return "" if self.zone.nil?
    return self.zone.name
  end
end # class MiqSchedule
