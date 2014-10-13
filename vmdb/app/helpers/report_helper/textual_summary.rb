module ReportHelper
  module TextualSummary
    def textual_miq_report_info
      items = []
      items.push('title')
      items.push('primary_record_filter') if @miq_report.conditions
      items.push('display_filter')        if @miq_report.display_filter
      items.push('sort_by')               if @miq_report.sortby
      items.push('chart')                 if @miq_report.graph
      items.push('based_on', 'user', 'group', 'updated_on')
      items.collect { |m| send("textual_#{m}") }.flatten.compact
    end

    def textual_title
      {:label => "Title", :value => @miq_report.title}
    end

    def textual_primary_record_filter
      {:label => "Primary (Record) Filter", :value => @miq_report.conditions.to_human}
    end

    def textual_display_filter
      {:label => "Secondary (Display) Filter", :value => @miq_report.display_filter.to_human}
    end

    def textual_sort_by
      sortby = @miq_report.sortby.collect do |s|
        Dictionary.gettext(s, :type => :column, :notfound => :titleize)
      end
      {:label => "Sort By", :value => sortby.join(", ")}
    end

    def textual_chart
      {:label => "Chart", :value =>  @miq_report.graph[:type]}
    end

    def textual_based_on
      {:label => "Based On",
       :value => Dictionary.gettext(@miq_report.db, :type => :model, :notfound => :titleize)}
    end

    def textual_user
      {:label => "User", :value => @miq_report.user.try(:userid) || ""}
    end

    def textual_group
      {:label => Dictionary.gettext("MiqGroup", :type => :model, :notfound => :titleize),
       :value => @miq_report.miq_group.try(:description) || ""}
    end

    def textual_updated_on
      {:label => "Updated On",
       :value => format_timezone(@miq_report.updated_on, Time.zone, "gtl")}
    end

    def textual_report_schedule_info
      items = %w(description active email_after_run)
      items.push('from_email', 'to_email') if @schedule.sched_action[:options] &&
                                              @schedule.sched_action[:options][:send_email] &&
                                              @schedule.sched_action[:options][:email]
      items.push('report_filter', 'run_at', 'last_run_time', 'next_run_time', 'zone')
      items.collect { |m| send("textual_sched_report_#{m}") }.flatten.compact
    end

    def textual_sched_report_description
      {:label => "Description", :value => @schedule.description}
    end

    def textual_sched_report_active
      {:label => "Active", :value => @schedule.enabled.to_s.capitalize}
    end

    def textual_sched_report_email_after_run
      row = {:label => "E-Mail after Running"}
      row[:value] = if @schedule.sched_action[:options] && @schedule.sched_action[:options][:send_email]
                      "True"
                    else
                      "False"
                    end
      row
    end

    def textual_sched_report_from_email
      row = {:label => "From E-mail"}
      row[:value] = if @schedule.sched_action[:options][:email][:from].blank?
                      "(Default: " + get_vmdb_config[:smtp][:from] + ")"
                    else
                      row[:value] = @schedule.sched_action[:options][:email][:from]
                    end
      row
    end

    def textual_sched_report_to_email
      row = {:label => "To E-mail"}
      row[:value] = @temp[:email_to].join(';') unless @temp[:email_to].blank?
      row
    end

    def textual_sched_report_report_filter
      {:label => "Report Filter", :value => @rep_filter}
    end

    def textual_sched_report_run_at
      {:label => "Run At", :value => @schedule.run_at_to_human(@timezone).to_s}
    end

    def textual_sched_report_last_run_time
      row = {:label => "Last Run Time"}
      row[:value] = format_timezone(@schedule.last_run_on, @timezone, "view") unless @schedule.last_run_on.blank?
      row
    end

    def textual_sched_report_next_run_time
      row = {:label => "Next Run Time"}
      row[:value] = format_timezone(@schedule.next_run_on, @timezone, "view") unless @schedule.next_run_on.blank?
      row
    end

    def textual_sched_report_zone
      {:label => "Zone", :value => @schedule.v_zone_name}
    end
  end
end
