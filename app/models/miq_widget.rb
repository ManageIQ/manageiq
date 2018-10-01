# Dashboard widget
#
require 'simple-rss'

class MiqWidget < ApplicationRecord
  default_value_for :enabled, true
  default_value_for :read_only, false

  DEFAULT_ROW_COUNT = 5
  IMPORT_CLASS_NAMES = %w(MiqWidget).freeze

  belongs_to :resource, :polymorphic => true
  belongs_to :miq_schedule
  belongs_to :user
  belongs_to :miq_task
  has_many   :miq_widget_contents, :dependent => :destroy

  has_many   :miq_widget_shortcuts, :dependent => :destroy
  has_many   :miq_shortcuts, :through => :miq_widget_shortcuts

  validates_presence_of   :title, :description
  validates_uniqueness_of :description
  VALID_CONTENT_TYPES = %w( report chart rss menu )
  validates_inclusion_of :content_type, :in => VALID_CONTENT_TYPES, :message => "should be one of #{VALID_CONTENT_TYPES.join(", ")}"

  serialize :visibility
  serialize :options

  scope :with_content_type, ->(type) { where(:content_type => type) }

  include_concern 'ImportExport'
  include UuidMixin
  include YAMLImportExportMixin
  acts_as_miq_set_member

  WIDGET_DIR =  File.expand_path(File.join(Rails.root, "product/dashboard/widgets"))

  before_destroy :destroy_schedule

  def destroy_schedule
    miq_schedule.destroy if miq_schedule
  end

  virtual_column :status,         :type => :string,    :uses => :miq_task
  virtual_delegate :status_message, :to => "miq_task.message", :allow_nil => true, :default => "Unknown"
  virtual_delegate :queued_at, :to => "miq_task.created_on", :allow_nil => true
  virtual_column :last_run_on,    :type => :datetime,  :uses => :miq_schedule

  def row_count(row_count_param = nil)
    row_count_param.try(:to_i) || options.try(:[], :row_count) || DEFAULT_ROW_COUNT
  end

  alias_attribute :name, :description

  def last_run_on
    last_generated_content_on || (miq_schedule && miq_schedule.last_run_on)
  end

  delegate :next_run_on, :to => :miq_schedule, :allow_nil => true

  def status
    if miq_task.nil?
      return "None" if last_run_on.nil?
      return "Complete"
    end
    miq_task.human_status
  end

  def create_task(num_targets, userid = User.current_userid)
    userid ||= "system"
    context_data = {:targets  => num_targets, :complete => 0}
    miq_task     = MiqTask.create(
      :name         => "Generate Widget: '#{title}'",
      :state        => MiqTask::STATE_QUEUED,
      :status       => MiqTask::STATUS_OK,
      :message      => "Task has been queued",
      :pct_complete => 0,
      :userid       => userid,
      :context_data => context_data
    )

    _log.info("Created MiqTask ID: [#{miq_task.id}], Name: [#{miq_task.name}] for: [#{num_targets}] groups")

    self.miq_task_id = miq_task.id
    self.save!

    miq_task
  end

  def generate_content_options(group, users)
    content_option_generator.generate(group, users, timezone_matters?)
  end

  def timeout_stalled_task
    return unless miq_task && miq_task.state != MiqTask::STATE_FINISHED &&
                  !MiqQueue.where(:method_name => "generate_content",
                                  :class_name  => self.class.name,
                                  :instance_id => id).any?(&:unfinished?)
    miq_task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_TIMEOUT, "Timed out stalled task.")
  end

  def queue_generate_content_for_users_or_group(*args)
    callback = {}
    if miq_task_id
      cb = {:class_name => self.class.name, :instance_id => id, :method_name => :generate_content_complete_callback}
      callback[:miq_callback] = cb
    end
    MiqQueue.create_with(callback).put_unless_exists(
      :queue_name  => "reporting",
      :role        => "reporting",
      :zone        => nil, # any zone
      :class_name  => self.class.to_s,
      :instance_id => id,
      :msg_timeout => 3600,
      :method_name => "generate_content",
      :args        => [*args]
    )
  end

  def generate_content_complete_callback(status, _message, _result)
    _log.info("Widget ID: [#{id}], MiqTask ID: [#{miq_task_id}], Status: [#{status}]")

    miq_task.lock(:exclusive) do |locked_miq_task|
      if MiqTask.status_error?(status)
        locked_miq_task.context_data[:error] ||= 0
        locked_miq_task.context_data[:error] += 1
      end

      if MiqTask.status_timeout?(status)
        locked_miq_task.context_data[:timeout] ||= 0
        locked_miq_task.context_data[:timeout] += 1
      end

      locked_miq_task.context_data[:complete] ||= 0
      locked_miq_task.context_data[:complete] += 1
      locked_miq_task.pct_complete = 100 * locked_miq_task.context_data[:complete] / locked_miq_task.context_data[:targets]

      if locked_miq_task.context_data[:complete] == locked_miq_task.context_data[:targets]
        task_status = MiqTask::STATUS_OK
        task_status = MiqTask::STATUS_TIMEOUT if locked_miq_task.context_data.key?(:timeout)
        task_status = MiqTask::STATUS_ERROR   if locked_miq_task.context_data.key?(:error)

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
    message << " (#{miq_task.context_data[:error]} in Error)"    if miq_task.context_data.key?(:error)
    message << " (#{miq_task.context_data[:timeout]} Timed Out)" if miq_task.context_data.key?(:timeout)
    message
  end

  def generate_content_update_message
    message  = "Widget Generation for #{miq_task.context_data[:complete]} of #{miq_task.context_data[:targets]} groups Complete"
    message << " (#{miq_task.context_data[:error]} in Error)"    if miq_task.context_data.key?(:error)
    message << " (#{miq_task.context_data[:timeout]} Timed Out)" if miq_task.context_data.key?(:timeout)
    message
  end

  def log_prefix
    "Widget: [#{title}] ID: [#{id}]"
  end

  def queue_generate_content
    return if content_type == "menu"
    # Called from schedule
    unless self.enabled?
      _log.info("#{log_prefix} is disabled, content will NOT be generated")
      return
    end

    group_hash_visibility_agnostic = grouped_subscribers
    if group_hash_visibility_agnostic.empty?
      _log.info("#{log_prefix} has no subscribers, content will NOT be generated")
      return
    end

    MiqPreloader.preload(group_hash_visibility_agnostic.keys, [:miq_user_role])

    group_hash = group_hash_visibility_agnostic.select { |k, _v| available_for_group?(k) }      # Process users grouped by LDAP group membership of whether they have RBAC

    if group_hash.length == 0
      _log.info("#{log_prefix} is not subscribed, content will NOT be generated")
      return
    end

    if ::Settings.product.report_sync
      group_hash.each do |g, u|
        options = generate_content_options(g, u)
        generate_content(*options)
      end
    else
      timeout_stalled_task
      unless MiqTask.exists?(:name   => "Generate Widget: '#{title}'",
                             :userid => User.current_userid || 'system',
                             :state  => %w(Queued Active))
        create_task(group_hash.length)

        _log.info("#{log_prefix} Queueing Content Generation")
        group_hash.each do |g, u|
          options = generate_content_options(g, u)
          queue_generate_content_for_users_or_group(*options)
        end
      end
    end
  end

  def generate_content(klass, group_description, userids, timezones = nil)
    return if content_type == "menu"
    miq_task.state_active if miq_task
    content_generator.generate(self, klass, group_description, userids, timezones)
  end

  def generate_one_content_for_group(group, timezone)
    _log.info("#{log_prefix} for [#{group.class}] [#{group.name}]...")

    begin
      content_type_klass = "MiqWidget::#{content_type.capitalize}Content".constantize
    rescue NameError
      _log.error("#{log_prefix} Unsupported content type '#{content_type}'")
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
      _log.error("#{log_prefix} Failed for [#{group.class}] [#{group.name}] with error: [#{error.class.name}] [#{error}]")
      _log.log_backtrace(error)
      return
    end

    _log.info("#{log_prefix} for [#{group.class}] [#{group.name}]...Complete")
    content
  end

  def generate_one_content_for_user(group, userid)
    _log.info("#{log_prefix} for group: [#{group.name}] users: [#{userid}]...")

    user = userid
    user = User.in_my_region.find_by(:userid => userid) if userid.kind_of?(String)
    if user.nil?
      _log.error("#{log_prefix} User #{userid} was not found")
      return
    end

    timezone = user.get_timezone
    if timezone.nil?
      _log.warn("#{log_prefix} No timezone provided for #{userid}! UTC will be used.")
      timezone = "UTC"
    end

    begin
      content_type_klass = "MiqWidget::#{content_type.capitalize}Content".constantize
    rescue NameError
      _log.error("#{log_prefix} Unsupported content type '#{content_type}'")
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
      _log.error("#{log_prefix} Failed for [#{user.class}] [#{user.name}] with error: [#{error.class.name}] [#{error}]")
      _log.log_backtrace(error)
      return
    end

    _log.info("#{log_prefix} for [#{group.name}] [#{userid}]...Complete")
    content
  end

  def generate_report(group, user = nil)
    rpt = resource.dup

    opts = {:miq_group_id => group.id}
    opts[:userid] = user.userid if user
    rpt.generate_table(opts)

    rpt
  end

  def generate_report_result(rpt, owner, timezone = nil)
    name = owner.respond_to?(:userid) ? owner.userid : owner.name
    group = owner.kind_of?(MiqGroup) ? owner : owner.try(:current_group)

    userid_for_result = "widget_id_#{id}|#{name}|schedule"
    MiqReportResult.purge_for_user(:userid => userid_for_result)

    rpt.build_create_results(:userid => userid_for_result, :report_source => "Generated for widget", :timezone => timezone, :miq_group_id => group.id)
  end

  def find_or_build_contents_for_user(group, user, timezone = nil)
    timezone = "UTC" if timezone && !timezone_matters?
    settings_for_build = {:miq_group_id => group.id}
    settings_for_build[:user_id]  = user.id  if user
    settings_for_build[:timezone] = timezone if timezone
    contents = contents_for_owner(group, user, timezone) || miq_widget_contents.build(settings_for_build)
    contents.updated_at = Time.now.utc # Force updated timestamp to change when saved even if the new contents are the same

    contents
  end

  # TODO: group/user support
  def create_initial_content_for_user(user, group = nil)
    return unless contents_for_user(user).blank? && content_type != "menu"  # Menu widgets have no content

    user    = self.class.get_user(user)
    group   = self.class.get_group(group)
    group ||= user.current_group

    options = generate_content_options(group, [user])
    if ::Settings.product.report_sync
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
    timezone = "UTC" if timezone && !timezone_matters?
    conditions = {:miq_group_id => group.id}
    conditions[:user_id]   = user.id if user
    conditions[:timezone] = timezone if timezone
    miq_widget_contents.find_by(conditions)
  end

  def contents_for_user(user)
    user = self.class.get_user(user)
    timezone = timezone_matters? ? user.get_timezone : "UTC"
    contents = contents_for_owner(user.current_group, user, timezone)
    contents ||= contents_for_owner(user.current_group, nil, timezone)
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
    groups_by_id    = MiqGroup.in_my_region.where(:id => grouped_users.keys).index_by(&:id)
    users_by_userid = User.in_my_region.where(:userid => grouped_users.values.flatten.uniq).index_by(&:userid)
    grouped_users.each_with_object({}) do |(k, v), h|
      user_objs = users_by_userid.values_at(*v).reject(&:blank?)
      h[groups_by_id[k]] = user_objs unless user_objs.blank?
    end
  end

  def available_for_group?(group)
    return false unless group
    has_visibility?(:roles, group.miq_user_role_name) || has_visibility?(:groups, group.description)
  end

  def self.available_for_user(user)
    user = get_user(user)
    role = user.miq_user_role_name
    group = user.current_group.description

    # Return all widgets that either has this user's role or is allowed for all roles, or has this user's group
    all.select do |w|
      w.has_visibility?(:roles, role) || w.has_visibility?(:groups, group)
    end
  end

  def self.available_for_group(group)
    group = get_group(group)
    role = group.miq_user_role_name
    # Return all widgets that either has this group's role or is allowed for all roles.
    all.select do |w|
      w.has_visibility?(:roles, role) || w.has_visibility?(:groups, group.description)
    end
  end

  def self.available_for_all_roles
    all.select { |w| w.visibility.key?(:roles) && w.visibility[:roles].include?("_ALL_") }
  end

  def has_visibility?(key, value)
    visibility.kind_of?(Hash) && visibility.key?(key) && (visibility[key].include?(value) || visibility[key].include?("_ALL_"))
  end

  def self.get_user(user)
    if user.kind_of?(String)
      original = user
      user = User.in_my_region.find_by_userid(user)
      _log.warn("Unable to find user '#{original}'") if user.nil?
    end

    user
  end

  def self.get_group(group)
    return nil if group.nil?

    original = group

    case group
    when String
      group = MiqGroup.in_my_region.find_by(:description => group)
    when Integer
      group = MiqGroup.in_my_region.find_by(:id => group)
    end

    _log.warn("Unable to find group '#{original}'") if group.nil?
    group
  end

  def self.sync_from_dir
    Dir.glob(File.join(WIDGET_DIR, "*.yaml")).sort.each { |f| sync_from_file(f) }
  end

  def self.sync_from_file(filename)
    attrs = YAML.load_file(filename)
    sync_from_hash(attrs.merge("filename" => filename))
  end

  def self.sync_from_hash(attrs)
    attrs.delete("id")
    filename = attrs.delete("filename")
    rname = attrs.delete("resource_name")
    if rname && attrs["resource_type"]
      klass = attrs.delete("resource_type").constantize
      attrs["resource"] = klass.find_by(:name => rname)
      raise _("Unable to find %{class} with name %{name}") % {:class => klass, :name => rname} unless attrs["resource"]
    end

    schedule_info = attrs.delete("miq_schedule_options")

    widget = find_by(:description => attrs["description"])
    if widget
      if filename
        $log.info("Widget: [#{widget.description}] file has been updated on disk, synchronizing with model")
        ["enabled", "visibility"].each { |a| attrs.delete(a) } # Don't updates these because they may have been modofoed by the end user.
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

  def set_rss_properties(feed_type, rss_feed_id = nil, url = nil)
    if feed_type == 'internal'
      self.resource = RssFeed.find(rss_feed_id) if rss_feed_id
      options.delete(:url)
    else
      options[:url] = url
      self.resource = nil
    end
  end

  def sync_schedule(schedule_info)
    return if schedule_info.nil?

    sched = miq_schedule
    return sched unless sched.nil?

    server_tz = MiqServer.my_server.server_timezone
    value     = schedule_info.fetch_path(:run_at, :interval, :value)
    unit      = schedule_info.fetch_path(:run_at, :interval, :unit)
    if unit == "daily"
      sched_time = (Time.now.in_time_zone(server_tz) + 1.day).beginning_of_day
    elsif unit == "hourly"
      ts = (Time.now.utc + 1.hour).iso8601
      ts[14..18] = "00:00"
      sched_time = ts.to_time(:utc).in_time_zone(server_tz)
    else
      raise _("Unsupported interval '%{interval}'") % {:interval => interval}
    end

    sched = MiqSchedule.create!(
      :name          => description,
      :description   => description,
      :sched_action  => {:method => "generate_widget"},
      :filter        => MiqExpression.new("=" => {"field" => "MiqWidget-id", "value" => id}),
      :resource_type => self.class.name,
      :run_at        => {
        :interval   => {:value => value, :unit  => unit},
        :tz         => server_tz,
        :start_time => sched_time
      },
    )
    self.miq_schedule = sched
    self.save!

    _log.info("Created schedule for Widget: [#{title}]")
    _log.debug("Widget: [#{title}] created schedule: [#{sched.inspect}]")

    sched
  end

  def self.seed
    sync_from_dir
  end

  def self.seed_widget(pattern)
    files = Dir.glob(File.join(WIDGET_DIR, "*#{pattern}*"))
    files.collect do |f|
      sync_from_file(f)
    end
  end

  def save_with_shortcuts(shortcuts)  # [[<shortcut.id>, <widget_shortcut.description>], ...]
    transaction do
      ws = []  # Create an array of widget shortcuts
      shortcuts.each_with_index do |s, s_idx|
        ws.push(MiqWidgetShortcut.new(:sequence => s_idx, :description => s.last, :miq_shortcut_id => s.first))
      end
      self.miq_widget_shortcuts = ws
      save       # .save! raises exception if validate_uniqueness fails
    end
    errors.empty? # True if no errors
  end

  def delete_legacy_contents_for_group(group)
    MiqWidgetContent.where(:miq_widget_id => id, :miq_group_id => group.id, :user_id => nil).destroy_all
  end

  # default: timezone does matter
  # options[:timezone_matters] == false will skip it
  # TODO: detect date field in the report?
  def timezone_matters?
    return true unless options
    options.fetch(:timezone_matters, true)
  end

  def self.display_name(number = 1)
    n_('Widget', 'Widgets', number)
  end

  private

  def content_generator
    @content_generator ||= MiqWidget::ContentGenerator.new
  end

  def content_option_generator
    @content_option_generator ||= MiqWidget::ContentOptionGenerator.new
  end
end
