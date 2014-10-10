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
  end
end
