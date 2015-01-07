class MiqReportResult < ActiveRecord::Base
  include_concern 'Purging'

  belongs_to :miq_report
  belongs_to :miq_group
  belongs_to :miq_task
  has_one    :binary_blob, :as => :resource, :dependent => :destroy
  has_many   :miq_report_result_details, :dependent => :delete_all
  has_many   :html_details, :class_name => "MiqReportResultDetail", :foreign_key => "miq_report_result_id", :conditions => "data_type = 'html'"

  serialize :report

  virtual_column :miq_group_description, :type => :string, :uses => :miq_group
  virtual_column :status,                :type => :string, :uses => :miq_task
  virtual_column :status_message,        :type => :string, :uses => :miq_task

  before_save do
    user_info = self.userid.to_s.split("|")
    if user_info.length == 1
      user = User.find_by_userid(user_info.first)
      self.miq_group_id = user.current_group_id unless user.nil?
    end
  end

  include ReportableMixin

  def status
    return "Unknown" if self.miq_task.nil?

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
        return "Finished"
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
    self.miq_task.nil? ? "Report results are no longer available" : self.miq_task.message
  end

  def miq_group_description
    self.miq_group ? self.miq_group.description : nil
  end

  def report_results
    if self.report.kind_of?(String)
      # support legacy reports that saved results in the report column
      return nil if self.report.nil?
      Marshal.load(Base64.decode64(self.report.split("\n").join))
    elsif self.binary_blob
      serializer_name = self.binary_blob.data_type
      serializer_name = "Marshal" unless serializer_name == "YAML"  # YAML or Marshal, for now
      serializer = serializer_name.constantize
      return serializer.load(self.binary_blob.binary)
    elsif self.report.kind_of?(MiqReport)
      return self.report
    else
      return nil
    end
  end

  def report_results=(value)
    self.binary_blob = BinaryBlob.new(:name => "report_results", :data_type => "YAML")
    self.binary_blob.binary = YAML.dump(value)
  end

  def report_html=(html)
    results = html.collect { |row| {:data_type => "html", :data => row} }
    self.miq_report_result_details.clear
    self.miq_report_result_details.build(results)
  end

  def html_rows(options={})
    per_page = options.delete(:per_page)
    page     = options.delete(:page) || 1
    unless per_page.nil?
      options[:offset] = ((page - 1) * per_page)
      options[:limit]  = per_page
    end
    self.update_attribute(:last_accessed_on, Time.now.utc)
    self.purge_for_user
    self.html_details.all(options.merge(:order => "id asc")).collect { |h| h.data }
  end

  def save_for_user(userid)
    self.update_attributes(:userid => userid, :report_source => "Saved by user")
  end

  # Encapsulate report in an array to prevent AR from serializing it as its ID
  # => See line 8 of vendor/gems/activerecord-2.2.2/lib/active_record/connection_adapters/abstract/quoting.rb -
  # => "records are quoted as their primary key"
  def report
    val = read_attribute(:report)
    val.nil? ? nil : val.first
  end

  def report=(val)
    write_attribute(:report, val.nil? ? nil : [val])
  end
  #

  def build_html_rows_for_legacy
    return if self.report && self.report.respond_to?(:extras) && self.report.extras.respond_to?(:has_key?) && self.report.extras.has_key?(:total_html_rows) && self.report.extras[:total_html_rows] != 0

    report = self.report_results
    self.report_html = report.build_html_rows

    report.extras ||= {}
    report.extras[:total_html_rows] = self.miq_report_result_details.length
    self.report = report

    self.save
  end

  def self.atStartup
    $log.info("MIQ(MiqReportResult.atStartup) Purging adhoc report results...")
    self.purge_for_user
    $log.info("MIQ(MiqReportResult.atStartup) Purging adhoc report results... complete")
  end

  #########################################################################################################
  # FIXME:  Hack because userid column is overridden with multiple column info using | character
  #
  # Examples:
  #    widget_id_12|ulee@manageiq.com|schedule
  #    ulee@manageiq.com|370709335b2b786aa1d2ac302dada217|adhoc
  #    ulee@manageiq.com
  #
  # Derived Specifications:
  #    widget_id_xx|userid|mode=schedule
  #    userid|session_id|mode=adhoc
  #    userid
  #########################################################################################################
  def self.parse_userid(userid)
    return userid unless userid.to_s.include?("|")
    parts = userid.to_s.split("|")
    return parts[0] if (parts.last == 'adhoc')
    return parts[1] if (parts.last == 'schedule')
    raise "Cannot parse userid #{userid.inspect}"
  end

  def self.purge_for_user(options={})
    options[:userid] ||= "%" # This will purge for all users
    cond = ["userid like ? and userid NOT like 'widget%' and last_accessed_on < ?", "#{options[:userid]}|%", 1.day.ago.utc]
    self.delete_all(cond)
  end

  def purge_for_user
    user = self.userid.split("|").first unless self.userid.nil?
    self.class.purge_for_user(:userid => user) unless user.nil?
  end

  def to_pdf
    page_size = "a4"
    if self.report.rpt_options && self.report.rpt_options[:pdf]
      page_size = self.report.rpt_options[:pdf][:page_size] || "a4"
    end

    curr_tz = Time.zone # Save current time zone setting
    user = self.userid.include?("|") ? nil : User.find_by_userid(self.userid)
    Time.zone = (user ? user.settings.fetch_path(:display, :timezone) : nil) || MiqServer.my_server.get_config("vmdb").config.fetch_path(:server, :timezone) || "UTC"

    # Create the pdf header section
    html_string = generate_pdf_header(
      :title     => self.name.gsub(/'/,'\\\\\&'), # Escape single quotes
      :page_size => page_size,
      :run_date  => format_timezone(self.last_run_on, Time.zone, "gtl")
    )

    Time.zone = curr_tz # Restore original time zone setting

    html_string << report_build_html_table(self.report_results, self.html_rows.join)  # Build the html report table using all html rows

    PdfGenerator.pdf_from_string(html_string, 'pdf_report')
  end

  # Generate the header html section for pdfs
  def generate_pdf_header(options={})
    page_size = options[:page_size] || "a4"
    title     = options[:title]     || "<No Title>"
    run_date  = options[:run_date]  || "<N/A>"

    hdr  = "<head><style>"
    hdr << "@page{size: #{page_size} landscape}"
    hdr << "@page{margin: 40pt 30pt 40pt 30pt}"
#   hdr << "@page{font-size: 50%}"
    hdr << "@page{@top{content: '#{title}';color:blue}}"
    hdr << "@page{@bottom-left{content: url('/images/layout/reportbanner_small1.png')}}"
    hdr << "@page{@bottom-center{font-size: 75%;content: 'Report date: #{run_date}'}}"
    hdr << "@page{@bottom-right{font-size: 75%;content: 'Page ' counter(page) ' of ' counter(pages)}}"
    hdr << "</style></head>"
  end

  def async_generate_result(result_type, options = {})
    # result_type => :csv | :txt | :pdf
    # options = {
    #   :userid => <userid>,
    #   :session_id => <session_id>
    # }
    log_prefix = "MIQ(MiqReportResult.async_generate_result)"

    raise "Result type #{result_type} not supported" unless [:csv, :txt, :pdf].include?(result_type.to_sym)
    raise "A valid userid is required" if options[:userid].nil?

    $log.info("#{log_prefix} Adding generate report result [#{result_type}] task to the message queue...")
    task = MiqTask.new(:name => "Generate Report result [#{result_type}]: '#{self.report.name}'", :userid => options[:userid])
    task.update_status("Queued", "Ok", "Task has been queued")

    sync = VMDB::Config.new("vmdb").config[:product][:report_sync]

    MiqQueue.put(
      :queue_name  => "generic",
      :role        => "reporting",
      :class_name  => self.class.name,
      :instance_id => self.id,
      :method_name => "_async_generate_result",
      :msg_timeout => self.report.queue_timeout,
      :args        => [task.id, result_type.to_sym, options],
      :priority    => MiqQueue::HIGH_PRIORITY
    ) unless sync
    self._async_generate_result(task.id, result_type.to_sym, options) if sync

    AuditEvent.success(
      :event        => "async_generate_result",
      :target_class => self.class.base_class.name,
      :target_id    => self.id,
      :userid       => options[:userid],
      :message      => "#{task.name}, successfully initiated"
    )

    $log.info("#{log_prefix} Finished adding generate report result [#{result_type}] task with id [#{task.id}] to the message queue")

    return task.id
  end

  def _async_generate_result(taskid, result_type, options = {})
    task = MiqTask.find_by_id(taskid)
    task.update_status("Active", "Ok", "Generating report result [#{result_type}]") if task

    user = User.find_by_userid(options[:userid])
    raise "Unable to find user with userid 'options[:userid]'" if user.nil?

    rpt = self.report_results
    begin
      userid = "#{options[:userid]}|#{options[:session_id]}|download"
      options[:report_source] = "Generated #{result_type} by user"
      self.class.purge_for_user(options)

      new_res = self.build_new_result(options.merge(:userid => userid))

      new_res.report_results = user.with_my_timezone do
        case result_type.to_sym
        when :csv then rpt.to_csv
        when :pdf then self.to_pdf
        when :txt then rpt.to_text
        else
          raise "Result type #{result_type} not supported"
        end
      end

      new_res.save
      task.miq_report_result = new_res

      task.save
      task.update_status("Finished", "Ok", "Generate Report result [#{result_type}]")
    rescue Exception => err
      $log.log_backtrace(err)
      task.error(err.message)
      task.state_finished
      raise
    end
  end

  def build_new_result(options)
    rpt = self.report_results # Get full report save with generated table

    ts = Time.now.utc
    attrs = {
      :name             => rpt.title,
      :userid           => options[:userid],
      :report_source    => options[:report_source],
      :db               => rpt.db,
      :last_run_on      => ts,
      :last_accessed_on => ts,
      :miq_report_id    => rpt.id,
      :report           => self.report # Report without generated table
    }

    $log.info("MIQ(MiqReportResult-build_new_result) Creating report results with hash: [#{attrs.inspect}]")
    res = MiqReportResult.find_by_userid(options[:userid]) if options[:userid].include?("|") # replace results if adhoc (<userid>|<session_id|<mode>) user report
    res = MiqReportResult.new if res.nil?
    res.attributes = attrs

    return res
  end

  def get_generated_result(result_type)
    # result_type => :csv | :txt | :pdf | :html
    # retrieve the resulting data based on type
    result_type.to_sym == :html ? self.html_rows : self.report_results
  end

  def self.counts_by_userid
    self.all(
      :conditions => "userid NOT LIKE 'widget%'",
      :select     => "userid, COUNT(id) as count",
      :group      => "userid"
    ).collect { |rr| {:userid => rr.userid, :count => rr.count.to_i} }
  end

  def self.orphaned_counts_by_userid
    self.counts_by_userid.reject { |h| User.exists?(:userid => h[:userid]) }
  end

  def self.delete_by_userid(userids)
    userids = userids.to_miq_a
    $log.info("MIQ(#{self.name}.delete_by_userid) Queuing deletion of report results for the following user ids: #{userids.inspect}")
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => "destroy_all",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [["userid IN (?)", userids]],
      :zone        => MiqServer.my_zone
    )
  end

  def self.find_all_by_users_group(userid)
    user = User.find_by_userid(userid)
    return [] if user.nil? || user.miq_group.nil?
    miq_report_ids = MiqReport.where("miq_group_id = ?", user.miq_group.id).pluck("id")

    MiqReportResult.all(
      :conditions => ["miq_report_id IN (?) AND report_source != ?", miq_report_ids, "Generated by user"],
      :select     => "miq_report_id, name",
      :group      => "miq_report_id, name"
    )
  end
end
