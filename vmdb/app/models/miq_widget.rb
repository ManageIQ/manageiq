# Dashboard widget
#
require 'simple-rss'

class MiqWidget < ActiveRecord::Base
  default_scope { where self.conditions_for_my_region_default_scope }

  default_value_for :enabled, true
  default_value_for :read_only, false

  belongs_to :resource, :polymorphic => true
  belongs_to :miq_schedule
  belongs_to :user
  belongs_to :miq_task
  has_many   :miq_widget_contents, :dependent => :destroy

  has_many   :miq_widget_shortcuts, :dependent => :destroy
  has_many   :miq_shortcuts, :through => :miq_widget_shortcuts

  validates_presence_of   :title, :description
  validates_uniqueness_of :description, :title
  VALID_CONTENT_TYPES = %w{ report chart rss menu }
  validates_inclusion_of :content_type, :in => VALID_CONTENT_TYPES, :message => "should be one of #{VALID_CONTENT_TYPES.join(", ")}"

  serialize :visibility
  serialize :options

  include_concern 'ImportExport'
  include ReportableMixin
  include UuidMixin
  include YAMLImportExportMixin
  acts_as_miq_set_member

  WIDGET_DIR =  File.expand_path(File.join(Rails.root, "product/dashboard/widgets"))

  before_destroy :destroy_schedule

  def destroy_schedule
    self.miq_schedule.destroy if self.miq_schedule
  end

  virtual_column :status,         :type => :string,    :uses => :miq_task
  virtual_column :status_message, :type => :string,    :uses => :miq_task
  virtual_column :queued_at,      :type => :datetime,  :uses => :miq_task
  virtual_column :last_run_on,    :type => :datetime,  :uses => :miq_schedule

  def name
    description
  end

  def last_run_on
    self.last_generated_content_on || (self.miq_schedule && self.miq_schedule.last_run_on)
  end

  def next_run_on
    self.miq_schedule && self.miq_schedule.next_run_on
  end

  def queued_at
    self.miq_task && self.miq_task.created_on
  end

  def status
    if self.miq_task.nil?
      return "None" if self.last_run_on.nil?
      return "Complete"
    end

    case self.miq_task.state
    when MiqTask::STATE_INITIALIZED
      return "Initialized"
    when MiqTask::STATE_QUEUED
      return "Queued"
    when MiqTask::STATE_ACTIVE
      return "Running"
    when MiqTask::STATE_FINISHED
      case self.miq_task.status
      when MiqTask::STATUS_OK
        return "Complete"
      when MiqTask::STATUS_WARNING
        return "Finished with Warnings"
      when MiqTask::STATUS_ERROR
        return "Error"
      when MiqTask::STATUS_TIMEOUT
        return "Timed Out"
      else
        raise "Unknown status of: #{self.miq_task.status.inspect}"
      end
    else
      raise "Unknown state of: #{self.miq_task.state.inspect}"
    end
  end

  def status_message
    self.miq_task.nil? ? "Unknown" : self.miq_task.message
  end

  # Returns status, last_run_on, message
  #   Status: None | Queued | Running | Complete
  def generation_status
    miq_task = self.miq_task

    if miq_task.nil?
      return "None" if self.last_run_on.nil?
      return "Complete", self.last_run_on
    end

    status =  case miq_task.state
              when MiqTask::STATE_QUEUED
                "Queued"
              when MiqTask::STATE_FINISHED
                "Complete"
              when MiqTask::STATE_ACTIVE
                "Running"
              else
                raise "Unknown state=#{miq_task.state.inspect}"
              end

    return status, self.last_run_on, miq_task.message
  end

  def create_task(num_targets, userid = User.current_userid)
    log_prefix = "MIQ(MiqWidget.create_task)"

    userid     ||= "system"
    context_data = { :targets  => num_targets, :complete => 0 }
    miq_task     = MiqTask.create(
                      :name         => "Generate Widget: '#{self.title}'",
                      :state        => MiqTask::STATE_QUEUED,
                      :status       => MiqTask::STATUS_OK,
                      :message      => "Task has been queued",
                      :pct_complete => 0,
                      :userid       => userid,
                      :context_data => context_data
                    )

    $log.info "#{log_prefix} Created MiqTask ID: [#{miq_task.id}], Name: [#{miq_task.name}] for: [#{num_targets}] groups"

    self.miq_task_id = miq_task.id
    self.save!

    return miq_task
  end

  def generate_content_options(group, users)
    content_option_generator.generate(group, users)
  end

  def timeout_stalled_task
    task = self.miq_task
    return unless task

    messages = MiqQueue.where(
      :method_name => "generate_content",
      :class_name  => self.class.name,
      :instance_id => self.id ).all

    unless messages.any?(&:unfinished?)
      unless task.state == MiqTask::STATE_FINISHED
        task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_TIMEOUT, "Timed out stalled task.")
      end
    end
  end

  def queue_generate_content_for_users_or_group(*args)
    MiqQueue.put_or_update(
      :queue_name   => "reporting",
      :role         => "reporting",
      :class_name   => self.class.to_s,
      :instance_id  => self.id,
      :msg_timeout  => 3600,
      :method_name  => "generate_content",
      :args         => [*args]
    ) do |msg, q_hash|
      if msg.nil?
        unless self.miq_task_id.nil?
          cb = { :class_name => self.class.name, :instance_id => self.id, :method_name => :generate_content_complete_callback }
          q_hash[:miq_callback] = cb
        end
        q_hash
      end
    end
  end

  def generate_content_complete_callback(status, message, result)
    log_prefix = "MIQ(MiqWidget.generate_content_complete_callback)"
    $log.info "#{log_prefix} Widget ID: [#{self.id}], MiqTask ID: [#{self.miq_task_id}], Status: [#{status}]"

    miq_task.lock(:exclusive) do |locked_miq_task|
      if MiqTask.status_error?(status)
        locked_miq_task.context_data[:error] ||= 0
        locked_miq_task.context_data[:error]  += 1
      end

      if MiqTask.status_timeout?(status)
        locked_miq_task.context_data[:timeout] ||= 0
        locked_miq_task.context_data[:timeout]  += 1
      end

      locked_miq_task.context_data[:complete] ||= 0
      locked_miq_task.context_data[:complete]  += 1
      locked_miq_task.pct_complete = 100 * locked_miq_task.context_data[:complete] / locked_miq_task.context_data[:targets]

      if locked_miq_task.context_data[:complete] == locked_miq_task.context_data[:targets]
        task_status = MiqTask::STATUS_OK
        task_status = MiqTask::STATUS_TIMEOUT if locked_miq_task.context_data.has_key?(:timeout)
        task_status = MiqTask::STATUS_ERROR   if locked_miq_task.context_data.has_key?(:error)

        locked_miq_task.update_status(MiqTask::STATE_FINISHED, task_status, generate_content_complete_message)
        generate_content_complete!
      else
        locked_miq_task.message = generate_content_update_message
      end

      locked_miq_task.save!
    end
  end

  def generate_content_complete!
    self.last_generated_content_on = Time.now.utc
    self.save!
  end

  def generate_content_complete_message
    message  = "Widget Generation for #{miq_task.context_data[:targets]} groups complete"
    message << " (#{miq_task.context_data[:error]} in Error)"    if miq_task.context_data.has_key?(:error)
    message << " (#{miq_task.context_data[:timeout]} Timed Out)" if miq_task.context_data.has_key?(:timeout)
    message
  end

  def generate_content_update_message
    message  = "Widget Generation for #{miq_task.context_data[:complete]} of #{miq_task.context_data[:targets]} groups Complete"
    message << " (#{miq_task.context_data[:error]} in Error)"    if miq_task.context_data.has_key?(:error)
    message << " (#{miq_task.context_data[:timeout]} Timed Out)" if miq_task.context_data.has_key?(:timeout)
    message
  end

  def queue_generate_content
    # Called from schedule
    log_prefix = "MIQ(#{self.class.name}.queue_generate_content) Widget: [#{self.title}], ID: [#{self.id}]"

    unless self.enabled?
      $log.info("#{log_prefix} is disabled, content will NOT be generated")
      return
    end

    group_hash_visibility_agnostic = grouped_subscribers
    if group_hash_visibility_agnostic.empty?
      $log.info("#{log_prefix} has no subscribers, content will NOT be generated")
      return
    end

    MiqPreloader.preload(group_hash_visibility_agnostic.keys, [:miq_user_role])

    group_hash = group_hash_visibility_agnostic.select { |k, v| available_for_group?(k) }      # Process users grouped by LDAP group membership of whether they have RBAC

    if group_hash.length == 0
      $log.info("#{log_prefix} is not subscribed, content will NOT be generated")
      return
    end

    if VMDB::Config.new("vmdb").config[:product][:report_sync]
      group_hash.each do |g,u|
        options = generate_content_options(g, u)
        generate_content(*options)
      end
    else
      timeout_stalled_task
      unless MiqTask.exists?(:name   => "Generate Widget: '#{title}'",
                             :userid => User.current_userid || 'system',
                             :state  => %w(Queued Active))
        create_task(group_hash.length)

        $log.info("#{log_prefix} Queueing Content Generation")
        group_hash.each do |g,u|
          options = generate_content_options(g, u)
          queue_generate_content_for_users_or_group(*options)
        end
      end
    end
  end

  def generate_content(klass, group_description, userids, timezones = nil)
    miq_task.state_active if miq_task
    content_generator.generate(self, klass, group_description, userids, timezones)
  end

  def generate_one_content_for_group(group, timezone)
    log_prefix = "MIQ(MiqWidget.generate_one_content_for_group) Widget: [#{title}] ID: [#{id}]"
    $log.info("#{log_prefix} for [#{group.class}] [#{group.name}]...")

    begin
      content_type_klass = "MiqWidget::#{content_type.capitalize}Content".constantize
    rescue NameError
      $log.error("#{log_prefix} Unsupported content type '#{content_type}'")
      return
    end

    begin
      if content_type_klass.based_on_miq_report?
        report = generate_report(group)
        miq_report_result = generate_report_result(report, group, timezone)
      end

      data = content_type_klass.new(:report => report, :resource => resource, :timezone => timezone, :widget_options => options).generate(group)
      content = find_or_build_contents_for_user(group, nil, timezone)
      content.miq_report_result = miq_report_result
      content.contents = data
      content.miq_group_id = group.id
      content.save!
    rescue => error
      $log.error("#{log_prefix} Failed for [#{group.class}] [#{group.name}] with error: [#{error.class.name}] [#{error}]")
      $log.log_backtrace(error)
      return
    end

    $log.info("#{log_prefix} for [#{group.class}] [#{group.name}]...Complete")
    content
  end

  def generate_one_content_for_user(group, userid)
    log_prefix = "MIQ(MiqWidget.generate_one_content_for_user) Widget: [#{title}] ID: [#{id}]"
    $log.info("#{log_prefix} for group: [#{group.name}] users: [#{userid}]...")

    user = userid
    if userid.kind_of?(String)
      user = User.in_my_region.where(:userid => userid).first
      if user.nil?
        $log.error("#{log_prefix} User #{userid} was not found")
        return
      end
    end

    timezone = user.get_timezone
    if timezone.nil?
      $log.warn "#{log_prefix} No timezone provided for #{userid}! UTC will be used."
      timezone = "UTC"
    end

    begin
      content_type_klass = "MiqWidget::#{content_type.capitalize}Content".constantize
    rescue NameError
      $log.error("#{log_prefix} Unsupported content type '#{content_type}'")
      return
    end

    begin
      if content_type_klass.based_on_miq_report?
        report = generate_report(group, user)
        miq_report_result = generate_report_result(report, user, timezone)
      end

      data = content_type_klass.new(:report => report, :resource => resource, :timezone => timezone, :widget_options => options).generate(user)
      content = find_or_build_contents_for_user(group, user, timezone)
      content.miq_report_result = miq_report_result
      content.contents = data
      content.user_id      = user.id
      content.miq_group_id = group.id
      content.save!
    rescue => error
      $log.error("#{log_prefix} Failed for [#{user.class}] [#{user.name}] with error: [#{error.class.name}] [#{error}]")
      $log.log_backtrace(error)
      return
    end

    $log.info("#{log_prefix} for [#{group.name}] [#{userid}]...Complete")
    content
  end

  def generate_report(group, user = nil)
    rpt = self.resource.dup

    opts = {:miq_group_id => group.id}
    opts[:userid] = user.userid if user
    rpt.generate_table(opts)

    rpt
  end

  def generate_report_result(rpt, owner, timezone = nil)
    name = owner.respond_to?(:userid) ? owner.userid : owner.name

    userid_for_result = "widget_id_#{self.id}|#{name}|schedule"
    MiqReportResult.purge_for_user(:userid => userid_for_result)

    rpt.build_create_results(:userid => userid_for_result, :report_source => "Generated for widget", :timezone => timezone)
  end

  def find_or_build_contents_for_user(group, user, timezone = nil)
    settings_for_build = {:miq_group_id => group.id}
    settings_for_build[:user_id]  = user.id  if user
    settings_for_build[:timezone] = timezone if timezone
    contents = contents_for_owner(group, user, timezone) || miq_widget_contents.build(settings_for_build)
    contents.updated_at = Time.now.utc # Force updated timestamp to change when saved even if the new contents are the same

    contents
  end

  #TODO: group/user support
  def create_initial_content_for_user(user, group = nil)
    return unless self.contents_for_user(user).blank? && self.content_type != "menu"  # Menu widgets have no content

    user    = self.class.get_user(user)
    group   = self.class.get_group(group)
    group ||= user.current_group

    options = generate_content_options(group, [user])
    if VMDB::Config.new("vmdb").config[:product][:report_sync]
      generate_content(*options)
    else
      timeout_stalled_task
      unless MiqTask.exists?(:name   => "Generate Widget: '#{title}'",
                             :userid => user.userid,
                             :state  => %w(Queued Active))
        create_task(1, user.userid)
        queue_generate_content_for_users_or_group(*options)
      end
    end
  end

  def contents_for_owner(group, user, timezone = nil)
    return unless group
    conditions = {:miq_group_id => group.id}
    conditions[:user_id]   = user.id if user
    conditions[:timezone] = timezone if timezone
    miq_widget_contents.where(conditions).first
  end

  def contents_for_user(user)
    user = self.class.get_user(user)
    contents = contents_for_owner(user.current_group, user, user.get_timezone)
    contents ||= contents_for_owner(user.current_group, nil, user.get_timezone)
    contents
  end

  def last_run_on_for_user(user)
    contents = contents_for_user(user)
    return nil if contents.nil?
    contents.miq_report_result.nil? ? contents.updated_at : contents.miq_report_result.last_run_on
  end

  def grouped_users_by_id
    id_groups = Hash.new { |h, k| h[k] = [] }
    memberof.compact.each_with_object(id_groups) do |ws, h|
      h[ws.group_id] << ws.userid unless ws.userid.blank? || ws.group_id.blank?
    end
  end

  def grouped_subscribers
    grouped_users   = grouped_users_by_id
    groups_by_id    = MiqGroup.where(:id => grouped_users.keys).index_by(&:id)
    users_by_userid = User.in_my_region.where(:userid => grouped_users.values.flatten.uniq).index_by(&:userid)
    grouped_users.each_with_object({}) do |(k, v), h|
      h[groups_by_id[k]] = users_by_userid.values_at(*v)
    end
  end

  def timezones_for_users(users)
    users.to_miq_a.collect(&:get_timezone).uniq.sort
  end

  def available_for_group?(group)
    return group ? has_visibility?(:roles, group.miq_user_role_name) : false
  end

  def self.available_for_user(user)
    user = self.get_user(user)
    role = user.miq_user_role_name || user.role.name
    group = user.miq_group_description

    # Return all widgets that either has this user's role or is allowed for all roles, or has this user's group
    self.all.select do |w|
      w.has_visibility?(:roles, role) || w.has_visibility?(:groups, group)
    end
  end

  def self.available_for_group(group)
    group = self.get_group(group)
    role = group.miq_user_role_name || group.role.name
    # Return all widgets that either has this group's role or is allowed for all roles.
    self.all.select do |w|
      w.has_visibility?(:roles, role) || w.has_visibility?(:groups, group.description)
    end
  end

  def self.available_for_all_roles
    self.all.select { |w| w.visibility.has_key?(:roles) && w.visibility[:roles].include?("_ALL_") }
  end

  def has_visibility?(key, value)
    self.visibility.kind_of?(Hash) && self.visibility.has_key?(key) && (self.visibility[key].include?(value) || self.visibility[key].include?("_ALL_"))
  end

  def self.get_user(user)
    if user.kind_of?(String)
      original = user
      user = User.in_my_region.find_by_userid(user)
      $log.warn("MIQ(MiqWidget.get_user) Unable to find user '#{original}'") if user.nil?
    end

    user
  end

  def self.get_group(group)
    original = group

    case group
    when String
      group = MiqGroup.in_my_region.find_by_description(group)
    when Fixnum
      group = MiqGroup.in_my_region.find_by_id(group)
    end

    $log.warn("MIQ(MiqWidget.get_group) Unable to find group '#{original}'") if group.nil?
    group
  end

  def self.sync_from_dir
    Dir.glob(File.join(WIDGET_DIR, "*.yaml")).sort.each {|f| self.sync_from_file(f)}
  end

  def self.sync_from_file(filename)
    attrs = YAML.load_file(filename)
    self.sync_from_hash(attrs.merge("filename" => filename))
  end

  def self.sync_from_hash(attrs)
    filename = attrs.delete("filename")
    rname = attrs.delete("resource_name")
    if rname && attrs["resource_type"]
      klass = attrs.delete("resource_type").constantize
      attrs["resource"] = klass.find_by_name(rname)
      raise "Unable to find #{klass} with name #{rname}" unless attrs["resource"]
    end

    schedule_info = attrs.delete("miq_schedule_options")

    widget = self.find_by_description(attrs["description"])
    if widget
      if filename && widget.updated_at.utc < File.mtime(filename).utc
        $log.info("Widget: [#{widget.description}] file has been updated on disk, synchronizing with model")
        ["enabled", "visibility"].each {|a| attrs.delete(a)} # Don't updates these because they may have been modofoed by the end user.
        widget.updated_at = Time.now.utc
        widget.update_attributes(attrs)
        widget.save!
      end
    else
      $log.info("Widget: [#{attrs["description"]}] file has been added to disk, adding to model")
      widget = self.create!(attrs)
    end

    widget.sync_schedule(schedule_info)
    widget
  end

  def sync_schedule(schedule_info)
    return if schedule_info.nil?

    sched = self.miq_schedule
    return sched unless sched.nil?

    server_tz = MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"
    value     = schedule_info.fetch_path(:run_at, :interval, :value)
    unit      = schedule_info.fetch_path(:run_at, :interval, :unit)
    if unit == "daily"
      sched_time = (Time.now.in_time_zone(server_tz) + 1.day).beginning_of_day
    elsif unit == "hourly"
      ts = (Time.now.utc + 1.hour).iso8601
      ts[14..18] = "00:00"
      sched_time = ts.to_time.in_time_zone(server_tz)
    else
      raise "Unsupported interval '#{interval}'"
    end

    sched = MiqSchedule.create!(
      :name           => self.title,
      :description    => self.description,
      :sched_action   => {:method => "generate_widget"},
      :filter         => MiqExpression.new({"=" => {"field" => "MiqWidget.id", "value" => self.id}}),
      :towhat         => self.class.name,
      :run_at         => {
        :interval     => {:value => value, :unit  => unit},
        :tz           => server_tz,
        :start_time   => sched_time
      },
    )
    self.miq_schedule = sched
    self.save!

    $log.info  "MIQ(MiqWidget.sync_schedule) Created schedule for Widget: [#{self.title}]"
    $log.debug "MIQ(MiqWidget.sync_schedule) Widget: [#{self.title}] created schedule: [#{sched.inspect}]"

    return sched
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.sync_from_dir
    end
    MiqWidgetSet.seed
  end

  def self.seed_widget(pattern)
    files = Dir.glob(File.join(WIDGET_DIR, "*#{pattern}*"))
    files.collect do |f|
      self.sync_from_file(f)
    end
  end

  def save_with_shortcuts(shortcuts)  # [[<shortcut.id>, <widget_shortcut.description>], ...]
    transaction do
      ws = Array.new  # Create an array of widget shortcuts
      shortcuts.each_with_index do |s, s_idx|
        ws.push(MiqWidgetShortcut.new(:sequence => s_idx, :description => s.last, :miq_shortcut_id => s.first))
      end
      self.miq_widget_shortcuts = ws
      self.save       # .save! raises exception if validate_uniqueness fails
    end
    return self.errors.empty? # True if no errors
  end

  def delete_legacy_contents_for_group(group)
    MiqWidgetContent.destroy_all(:miq_widget_id => self.id, :miq_group_id => group.id, :user_id => nil)
  end

  private

  def content_generator
    @content_generator ||= MiqWidget::ContentGenerator.new
  end

  def content_option_generator
    @content_option_generator ||= MiqWidget::ContentOptionGenerator.new
  end
end
