module ApplicationController::ReportDownloads
  extend ActiveSupport::Concern

  # Send the current report in text format
  def render_txt
    @report = report_for_rendering
    filename = filename_timestamp(@report.title)
    disable_client_cache
    send_data(@report.to_text,
              :filename => "#{filename}.txt")
  end

  # Send the current report in csv format
  def render_csv
    @report = report_for_rendering
    filename = filename_timestamp(@report.title)
    disable_client_cache
    send_data(@report.to_csv,
              :filename => "#{filename}.csv")
  end

  # Send the current report in pdf format
  def render_pdf(report = nil)
    report ||= report_for_rendering
    if report
      userid = "#{session[:userid]}|#{request.session_options[:id]}|adhoc"
      rr = report.build_create_results(:userid => userid)
    end

    # Use rr frorm paging, if present
    rr ||= MiqReportResult.find(@sb[:pages][:rr_id]) if @sb[:pages]
    # Use report_result_id in session, if present
    rr ||= MiqReportResult.find(session[:report_result_id]) if session[:report_result_id]

    filename = filename_timestamp(rr.report.title)
    disable_client_cache
    send_data(rr.to_pdf, :filename => "#{filename}.pdf", :type => 'application/pdf')
  end

  # Show the current widget report in pdf format
  def widget_to_pdf
    @report = nil   # setting report to nil in case full screen mode was opened first, to make sure the one in report_result is used for download
    session[:report_result_id] = params[:rr_id]
    render_pdf
  end

  # Render report in csv/txt/pdf format asynchronously
  def render_report_data
    render_type = RENDER_TYPES[params[:render_type]]
    assert_privileges("render_report_#{render_type}")
    unless params[:task_id] # First time thru, kick off the report generate task
      if render_type
        @sb[:render_type] = render_type
        rr = MiqReportResult.find(session[:report_result_id]) # Get report task id from the session
        task_id = rr.async_generate_result(@sb[:render_type], :userid     => session[:userid],
                                                              :session_id => request.session_options[:id])
        initiate_wait_for_task(:task_id => task_id)
      end
      return
    end

    miq_task = MiqTask.find(params[:task_id])
    if !miq_task.results_ready?
      add_flash(_("Report generation returned: Status [%{status}] Message [%{message}]") % {:status => miq_task.status, :message => miq_task.message}, :error)
      render :update do |page|
        page << javascript_prologue
        page << "if (miqDomElementExists('flash_msg_div_report_list')){"
        page.replace("flash_msg_div_report_list", :partial => "layouts/flash_msg",
                                                  :locals  => {:div_num => "_report_list"})
        page << "} else {"
        page.replace("flash_msg_div", :partial => "layouts/flash_msg")
        page << "}"
        page << "miqSparkle(false);"
      end
    else
      @sb[:render_rr_id] = miq_task.miq_report_result.id
      render :update do |page|
        page << javascript_prologue
        page << "miqSparkle(false);"
        page << "DoNav('#{url_for(:action => "send_report_data")}');"
      end
    end
  end
  alias_method :render_report_txt, :render_report_data
  alias_method :render_report_csv, :render_report_data
  alias_method :render_report_pdf, :render_report_data

  # Send rendered report data
  def send_report_data
    if @sb[:render_rr_id]
      rr = MiqReportResult.find(@sb[:render_rr_id])
      filename = filename_timestamp(rr.report.title, 'export_filename')
      disable_client_cache
      generated_result = rr.get_generated_result(@sb[:render_type])
      rr.destroy
      send_data(generated_result,
                :filename => "#{filename}.#{@sb[:render_type]}",
                :type     => "application/#{@sb[:render_type]}")
    end
  end

  # Download currently displayed view
  def download_data
    @view = session[:view].dup if session[:view] # Copy session view, if it exists
    options = session[:paged_view_search_options].merge(:page => nil, :per_page => nil) # Get all pages
    @view.table, _attrs = @view.paged_view_search(options) # Get the records

    @view.title = _(@view.title)
    @view.headers.map! { |header| _(header) }

    @filename = filename_timestamp(@view.title)
    case params[:download_type]
    when "pdf"
      download_pdf(@view)
    when "text"
      download_txt(@view)
    when "csv"
      download_csv(@view)
    end
  end

  private

  RENDER_TYPES = {'txt' => :txt, 'csv' => :csv, 'pdf' => :pdf}

  def download_txt(view)
    disable_client_cache
    send_data(view.to_text, :filename => "#{@filename}.txt")
  end

  def download_csv(view)
    disable_client_cache
    send_data(view.to_csv, :filename => "#{@filename}.csv")
  end

  # Send the current report in pdf format
  def download_pdf(view)
    render_pdf(view)
  end

  def report_for_rendering
    if session[:rpt_task_id]
      miq_task = MiqTask.find(session[:rpt_task_id])
      miq_task.task_results
    elsif session[:report_result_id]
      rr = MiqReportResult.find(session[:report_result_id])
      report = rr.report_results
      report.report_run_time = rr.last_run_on
      report
    end
  end

  def filename_timestamp(basename, format = 'fname')
    basename + '_' + format_timezone(Time.zone.now, Time.zone, format)
  end

  def set_summary_pdf_data
    @report_only = true
    @showtype    = @display
    run_time     = Time.now
    klass        = ui_lookup(:model => @record.class.name)

    @options = {
      :page_layout => "portrait",
      :page_size   => "us-letter",
      :run_date    => run_time.strftime("%m/%d/%y %l:%m %p %z"),
      :title       => "#{klass} \"#{@record.name}\"".html_safe,
    }

    if @display == "download_pdf"
      @display = "main"
      case @record
      when VmOrTemplate
        if @record.hardware.present?
          @record_notes = @record.hardware.annotation || "<No notes have been entered for this VM>"
        end
        get_host_for_vm(@record)
        set_config(@record)
      when ResourcePool
        # FIXME: check if this can be put before the test (can we have other
        # records than Vm and ResourcePool?)
        set_config(@record)
      end

      disable_client_cache
      html_string = render_to_string(:template => "/layouts/show_pdf", :layout => false)
      pdf_data = PdfGenerator.pdf_from_string(html_string, "pdf_summary")
      send_data(pdf_data,
                :type     => "application/pdf",
                :filename => filename_timestamp("#{klass}_#{@record.name}_summary") + '.pdf'
               )
    end
  end
end
