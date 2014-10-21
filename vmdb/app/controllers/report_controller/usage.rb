module ReportController::Usage
  extend ActiveSupport::Concern

  # Show VM usage
  def usage
    @breadcrumbs = Array.new
    drop_breadcrumb( {:name=>"VM Usage", :url=>"/report/usage"} )
    @lastaction = "usage"
    sdate, edate = VimUsage.first_and_last_capture
    @usage_options = session[:usage_options] ? session[:usage_options] : Hash.new
    if sdate.nil?
      @usage_options[:sdate] = @usage_options[:edate] = nil
      add_flash(_("No usage data found for specified options"), :error)
    else
      @usage_options[:typ]   ||= "daily"
      @usage_options[:cats]  ||= usage_build_cats
      @usage_options[:hours] ||= Array.new(24) {|i| i < 10 ? "0#{i}" : "#{i}"}
      @usage_options[:hour]  ||= "00"
      @usage_options[:sdate] ||= [sdate.year.to_s, (sdate.month - 1).to_s, sdate.day.to_s].join(", ")
      @usage_options[:edate] ||= [edate.year.to_s, (edate.month - 1).to_s, edate.day.to_s].join(", ")
      @usage_options[:report]  = nil

      usage_gen_report if @usage_options[:tag]
      session[:usage_options] = @usage_options
    end
  end

  # Process changes to usage report options
  def usage_option_chooser
    @usage_options = session[:usage_options]
    @usage_options[:report] = nil
    @usage_options[:typ] = params[:usage_typ] if params[:usage_typ]
    @usage_options[:date] = params[:miq_date_1] if params[:miq_date_1]
    @usage_options[:hour] = params[:usage_hour] if params[:usage_hour]
    if params[:usage_cat]
      @usage_options[:tag] = nil                    # Clear tag if category changed
      if params[:usage_cat] == "<Choose>"
        @usage_options[:cat] = nil
      else
        @usage_options[:cat] = params[:usage_cat]
        @usage_options[:tags] = usage_build_tags(@usage_options[:cat])
      end
    end
    if params[:usage_tag]
      if params[:usage_tag] == "<Choose>"
        @usage_options[:tag] = nil
      else
        @usage_options[:tag] = params[:usage_tag]
      end
    end
    if params[:usage_vmtype]
      @usage_options[:vmtype] = params[:usage_vmtype] == "<All>" ? nil : params[:usage_vmtype]
    end

    usage_gen_report if @usage_options[:tag]
    session[:usage_options] = @usage_options

    render :update do |page|
#     if new_toolbars
        if @usage_options[:report] && @usage_options[:report].table.data.length > 0
          page << "center_tb.showItem('usage_txt');"
          page << "center_tb.enableItem('usage_txt');"
          page << "center_tb.showItem('usage_csv');"
          page << "center_tb.enableItem('usage_csv');"
          page << "center_tb.showItem('usage_pdf');"
          page << "center_tb.enableItem('usage_pdf');"
          page << "center_tb.showItem('usage_reportonly');"
          page << "center_tb.enableItem('usage_reportonly');"
        else
          page << "center_tb.hideItem('usage_txt');"
          page << "center_tb.hideItem('usage_csv');"
          page << "center_tb.hideItem('usage_pdf');"
          page << "center_tb.hideItem('usage_reportonly');"
        end
#     else
#       page.replace_html("center_buttons_div", :partial=>"layouts/center_buttons")
#     end
      page.replace("flash_msg_div", :partial=>"layouts/flash_msg")
      page.replace("usage_options_div", :partial=>"usage_options")
      page.replace("usage_report_div", :partial=>"usage_report")
      page << 'miqBuildCalendar();'
      page << 'miqSparkle(false);'
    end
  end

  # Send the current report in text, CSV, or PDF
  def usage_download
    report = session[:usage_options][:report]
#   filename = report.title + "_" + Time.now.strftime("%Y_%m_%d")
    filename = report.title
    disable_client_cache
    case params[:typ]
    when "txt"
      send_data(report.to_text,
        :filename => "#{filename}.txt" )
    when "csv"
      send_data(report.to_csv,
        :filename => "#{filename}.csv" )
    when "pdf"
      download_pdf(report)
    end
  end

  # Display a usage report standalone
  def usage_report_only
    @usage_options = session[:usage_options]
    @report_only = true                             # Indicate stand alone report for views
    report = @usage_options[:report]
    @html = report.to_html
    render :action=>"usage"
  end

  private

  # Load a chart miq_report object from YML
  def usage_get_rpt(chart_rpt)
    return MiqReport.new(YAML::load(File.open("#{USAGE_REPORTS_FOLDER}/#{chart_rpt.to_s}.yaml")))
  end

  # Build the category pulldown for usage report
  def usage_build_cats
#   cats = Classification.categories.sort{|a,b| a.description <=> b.description}  # Get the categories, sort by name
    cats = Classification.categories.collect {|c| c unless !c.show}.compact                                             # Get the categories
    cats.delete_if{ |c| c.read_only? || c.entries.length == 0}              # Remove categories that are read only or have no entries
    ret_cats = {"<Choose>"=>"<Choose>"}                                           # Classifications hash for chooser
    cats.each {|c| ret_cats[c.name] = c.description}                              # Add categories to the hash
    return ret_cats
  end

  # Build the tag pulldown for usage report
  def usage_build_tags(cat)
    cat = Classification.find_by_name(params[:usage_cat])
    ret_tags = {"<Choose>"=>"<Choose>"}                                           # Tags hash for chooser
    cat.entries.each {|e| ret_tags[e.name] = e.description}                       # Add category tags to the hash
    return ret_tags
  end

  # Generate the html report based on the usage options
  def usage_gen_report
    rpt = @usage_options[:typ] == "hourly" ? usage_get_rpt("vim_usage_hour") : usage_get_rpt("vim_usage_day")
    ts = @usage_options[:typ] == "hourly" ? "#{@usage_options[:date]} #{@usage_options[:hour]}:00:00" : @usage_options[:date]
    rpt.performance = {
      :timestamp => ts,
      :interval_name => @usage_options[:typ],
      :group_by_category => @usage_options[:cat],
      :group_by_tag => @usage_options[:tag]
    }
    rpt.generate_table(:userid => session[:userid])
    rpt.title = "VM Usage for #{@usage_options[:cats][@usage_options[:cat]]}: #{@usage_options[:tags][@usage_options[:tag]]} on #{@usage_options[:date]}" +
      (@usage_options[:typ] == "daily" ? "" : " at #{@usage_options[:hour]}:00")

    if rpt.table.data.length == 0
      add_flash(_("No usage data found for specified options"), :error)
    end
    @usage_options[:report] = rpt
    @html = rpt.to_html             # Create html from the usage report
  end

end
