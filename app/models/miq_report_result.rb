class MiqReportResult < ApplicationRecord
  include_concern 'Purging'
  include_concern 'ResultSetOperations'

  belongs_to :miq_report
  belongs_to :miq_group
  belongs_to :miq_task
  has_one    :binary_blob, :as => :resource, :dependent => :destroy
  has_one    :miq_widget_content, :dependent => :nullify
  has_many   :miq_report_result_details, :dependent => :delete_all
  has_many   :html_details, -> { where("data_type = 'html'") }, :class_name => "MiqReportResultDetail", :foreign_key => "miq_report_result_id"

  serialize :report

  virtual_delegate :description, :to => :miq_group, :prefix => true, :allow_nil => true, :type => :string
  virtual_attribute :status, :string
  virtual_column :status_message,        :type => :string, :uses => :miq_task
  virtual_has_one :result_set,           :class_name => "Hash"

  scope :for_groups, lambda { |group_ids|
    condition = {:miq_group_id => group_ids}
    if group_ids.nil?
      where.not(condition)
    else
      where(condition)
    end
  }
  scope :for_user, lambda { |user|
    for_groups(user.report_admin_user? ? nil : user.miq_group_ids)
  }

  before_save do
    user_info = userid.to_s.split("|")
    if user_info.length == 1
      user = User.lookup_by_userid(user_info.first)
      self.miq_group_id ||= user.current_group_id unless user.nil?
    end
  end

  # These two hooks prevent temporary chargeback aggregation data to be
  # retained in each miq_report_results row, which was found and fixed as part
  # of the following BZ:
  #
  #   https://bugzilla.redhat.com/show_bug.cgi?id=1590908
  #
  # These two hooks remove extra data on the `@extras` instance variable, since
  # it is not necessary to be saved to the DB, but allows it to be retained for
  # the remainder of the object's instantiation.  The `after_commit` hook
  # specifically is probably overkill, but allows us to not break existing code
  # that expects the temporary chargeback data in the instantiated object.
  before_save  { @_extra_groupings = report.extras.delete(:grouping) if report.kind_of?(MiqReport) && report.extras }
  after_commit { report.extras[:grouping] = @_extra_groupings if report.kind_of?(MiqReport) && report.extras }

  delegate :table, :to => :report_results, :allow_nil => true

  def result_set_for_reporting(options)
    self.class.result_set_for_reporting(self, options)
  end

  def report_or_miq_report
    report || miq_report
  end

  def friendly_title
    report_source == MiqWidget::WIDGET_REPORT_SOURCE && miq_widget_content ? miq_widget_content.miq_widget.title : report.title
  end

  def result_set
    (table || []).map(&:to_hash)
  end

  def status
    if miq_task
      miq_task.human_status
    else
      report_results_blank? ? "Error" : "Complete"
    end
  end

  # This method doesn't run through all binary blob parts to determine if it has any
  def report_results_blank?
    if binary_blob
      binary_blob.parts.zero?
    elsif report.kind_of?(MiqReport)
      report.blank?
    end
  end

  def status_message
    miq_task.nil? ? _("The task associated with this report is no longer available") : miq_task.message
  end

  # Use this method over `report_results` if you don't plan on using the
  # `binary_blob` associated with the MiqReportResult (chances are you don't
  # need it).
  def valid_report_column?
    report.kind_of?(MiqReport)
  end

  # Use this over `report_results.contains_records?` if you don't need to
  # access the binary_blob associated with the MiqReportResult (chances are you
  # don't need it)
  def contains_records?
    (report && (report.extras || {})[:total_html_rows].to_i.positive?) || html_details.exists?
  end

  def report_results
    if binary_blob
      data = binary_blob.data
      data.kind_of?(Hash) ? MiqReport.from_hash(data) : data
    elsif report.kind_of?(MiqReport)
      report
    end
  end

  def report_results=(value)
    build_binary_blob(:name => "report_results")
    binary_blob.store_data("YAML", value.kind_of?(MiqReport) ? value.to_hash : value)
  end

  def report_html=(html)
    results = html.collect { |row| {:data_type => "html", :data => row} }
    miq_report_result_details.clear
    miq_report_result_details.build(results)
  end

  # @option options :per_page number of items per page
  # @option options :page page number (defaults to page 1)
  def html_rows(options = {})
    per_page = options.delete(:per_page)
    page     = options.delete(:page) || 1
    unless per_page.nil?
      options[:offset] = ((page - 1) * per_page)
      options[:limit]  = per_page
    end
    update_attribute(:last_accessed_on, Time.now.utc)
    purge_for_user
    html_details.order("id asc").offset(options[:offset]).limit(options[:limit]).collect(&:data)
  end

  def save_for_user(userid)
    update(:userid => userid, :report_source => "Saved by user")
  end

  def report
    val = read_attribute(:report)
    return if val.nil?

    MiqReport.from_hash(val)
  end

  def report=(val)
    write_attribute(:report, val.try(:to_hash))
  end

  def build_html_rows_for_legacy
    return if report && report.respond_to?(:extras) && report.extras.respond_to?(:has_key?) && report.extras.key?(:total_html_rows) && report.extras[:total_html_rows] != 0

    report = report_results
    self.report_html = report.build_html_rows

    report.extras ||= {}
    report.extras[:total_html_rows] = miq_report_result_details.length
    self.report = report

    save
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
    raise _("Cannot parse userid %{user_id}") % {:user_id => userid.inspect}
  end

  def self.purge_for_all_users
    purge_for_user(:userid => "%")
  end

  def self.purge_for_user(options = {})
    options[:userid] ||= "%" # This will purge for all users
    cond = ["userid like ? and userid NOT like 'widget%' and last_accessed_on < ?", "#{options[:userid]}|%", 1.day.ago.utc]
    where(cond).delete_all
  end

  def purge_for_user
    user = userid.split("|").first unless userid.nil?
    self.class.purge_for_user(:userid => user) unless user.nil?
  end

  def to_pdf
    # Create the pdf header section
    html_string = generate_pdf_header(
      :title     => name.gsub(/'/, '\\\\\&'), # Escape single quotes
      :page_size => report.page_size,
      :run_date  => format_timezone(last_run_on, user_timezone, "gtl")
    )

    html_string << report_build_html_table(report_results, html_rows.join)  # Build the html report table using all html rows

    PdfGenerator.pdf_from_string(html_string, "pdf_report.css")
  end

  # Generate the header html section for pdfs
  def generate_pdf_header(options = {})
    page_size = options[:page_size] || "a4"
    title     = options[:title] || _("<No Title>")
    run_date  = options[:run_date] || "<N/A>"

    hdr  = "<head><style>"
    hdr << "@page{size: #{page_size} landscape}"
    hdr << "@page{margin: 40pt 30pt 40pt 30pt}"
    hdr << "@page{@top{content: '#{title}';color:blue}}"
    hdr << "@page{@bottom-center{font-size: 75%;content: '" + _("Report date: %{report_date}") % {:report_date => run_date} + "'}}"
    hdr << "@page{@bottom-right{font-size: 75%;content: '" + _("Page %{page_number} of %{total_pages}") % {:page_number => " ' counter(page) '", :total_pages => " ' counter(pages)}}"}
    hdr << "</style></head>"
  end

  def async_generate_result(result_type, options = {})
    # result_type => :csv | :txt | :pdf
    # options = {
    #   :userid => <userid>,
    #   :session_id => <session_id>
    # }

    unless [:csv, :txt, :pdf].include?(result_type.to_sym)
      raise _("Result type %{result_type} not supported") % {:result_type => result_type}
    end
    raise _("A valid userid is required") if options[:userid].nil?

    _log.info("Adding generate report result [#{result_type}] task to the message queue...")
    task = MiqTask.new(:name => "Generate Report result [#{result_type}]: '#{report.name}'", :userid => options[:userid])
    task.update_status("Queued", "Ok", "Task has been queued")

    sync = ::Settings.product.report_sync

    MiqQueue.submit_job(
      :service     => "reporting",
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => "_async_generate_result",
      :msg_timeout => report.queue_timeout,
      :args        => [task.id, result_type.to_sym, options],
      :priority    => MiqQueue::HIGH_PRIORITY
    ) unless sync
    _async_generate_result(task.id, result_type.to_sym, options) if sync

    AuditEvent.success(
      :event        => "async_generate_result",
      :target_class => self.class.base_class.name,
      :target_id    => id,
      :userid       => options[:userid],
      :message      => "#{task.name}, successfully initiated"
    )

    _log.info("Finished adding generate report result [#{result_type}] task with id [#{task.id}] to the message queue")

    task.id
  end

  def _async_generate_result(taskid, result_type, options = {})
    task = MiqTask.find_by(:id => taskid)
    task.update_status("Active", "Ok", "Generating report result [#{result_type}]") if task

    user = options[:user] || User.lookup_by_userid(options[:userid])
    raise _("Unable to find user with userid 'options[:userid]'") if user.nil?

    rpt = report_results
    begin
      userid = "#{user.userid}|#{options[:session_id]}|download"
      options[:report_source] = "Generated #{result_type} by user"
      self.class.purge_for_user(options)

      new_res = build_new_result(options.merge(:userid => userid))

      # temporarily stick last_run_on time into report object
      # to be used by report_formatter while generating downloadable text report
      if result_type.to_sym == :txt
        rpt.rpt_options ||= {}
        rpt.rpt_options[:last_run_on] = last_run_on
      end

      new_res.report_results = user.with_my_timezone do
        case result_type.to_sym
        when :csv then rpt.to_csv
        when :pdf then html_rows.join
        when :txt then rpt.to_text
        else
          raise _("Result type %{result_type} not supported") % {:result_type => result_type}
        end
      end

      new_res.save
      task.miq_report_result = new_res

      task.save
      task.update_status("Finished", "Ok", "Generate Report result [#{result_type}]")
    rescue Exception => err
      _log.log_backtrace(err)
      task.error(err.message)
      task.state_finished
      raise
    end
  end

  def build_new_result(options)
    rpt = report_results # Get full report save with generated table

    ts = Time.now.utc
    attrs = {
      :name             => rpt.title,
      :userid           => options[:userid],
      :report_source    => options[:report_source],
      :db               => rpt.db,
      :last_run_on      => ts,
      :last_accessed_on => ts,
      :miq_report_id    => rpt.id,
      :report           => report # Report without generated table
    }

    _log.info("Creating report results with hash: [#{attrs.inspect}]")
    res = MiqReportResult.find_by_userid(options[:userid]) if options[:userid].include?("|") # replace results if adhoc (<userid>|<session_id|<mode>) user report
    res = MiqReportResult.new if res.nil?
    res.attributes = attrs

    res
  end

  def get_generated_result(result_type)
    # result_type => :csv | :txt | :pdf | :html
    # retrieve the resulting data based on type
    result_type.to_sym == :html ? html_rows : report_results
  end

  def self.counts_by_userid
    where("userid NOT LIKE 'widget%'").select("userid, COUNT(id) as count").group("userid")
      .collect { |rr| {:userid => rr.userid, :count => rr.count.to_i} }
  end

  def self.orphaned_counts_by_userid
    counts_by_userid.reject { |h| User.exists?(:userid => h[:userid]) }
  end

  def self.delete_by_userid(userids)
    userids = Array.wrap(userids.presence)
    _log.info("Queuing deletion of report results for the following user ids: #{userids.inspect}")
    MiqQueue.submit_job(
      :class_name  => name,
      :method_name => "destroy_all",
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args        => [["userid IN (?)", userids]],
    )
  end

  def self.auto_generated
    where.not(:report_source => "Generated by user")
  end

  def self.with_current_user_groups_and_report(report_id = nil)
    with_report(report_id).with_current_user_groups
  end

  def self.with_report(report_id = nil)
    report_id.nil? ? where.not(:miq_report_id => nil) : where(:miq_report_id => report_id)
  end

  def self.with_current_user_groups
    current_user = User.current_user
    for_groups(current_user.report_admin_user? ? nil : current_user.miq_group_ids)
  end

  def self.with_chargeback
    includes(:miq_report).where(:miq_reports => {:db => Chargeback.subclasses.collect(&:name)})
  end

  def self.with_saved_chargeback_reports(report_id = nil)
    with_report(report_id).auto_generated.with_current_user_groups.with_chargeback.order(Arel.sql('LOWER(miq_reports.name)'))
  end

  def self.select_distinct_results
    select("DISTINCT ON(LOWER(miq_reports.name), miq_report_results.miq_report_id) LOWER(miq_reports.name), \
            miq_report_results.miq_report_id")
  end

  def self.display_name(number = 1)
    n_('Report Result', 'Report Results', number)
  end

  def user_timezone
    user = userid.include?("|") ? nil : User.lookup_by_userid(userid)
    user ? user.get_timezone : MiqServer.my_server.server_timezone
  end
end
