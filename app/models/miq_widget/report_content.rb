class MiqWidget::ReportContent < MiqWidget::ContentGeneration
  def generate(user_or_group)
    report.rpt_options ||= {}
    report.col_formats ||= {}
    self.widget_options ||= {}

    original_col_order = report.col_order
    report.col_order   = widget_options[:col_order] if widget_options[:col_order]
    row_count   = widget_options[:row_count] || MiqWidget::DEFAULT_ROW_COUNT

    headers     = report.col_order.inject([]) { |a, c| a << report.headers[original_col_order.index(c)] }
    col_formats = report.col_order.inject([]) { |a, c| a << report.col_formats[original_col_order.index(c)] }

    report.col_formats = col_formats           # Use widget's column formats

    report.rpt_options[:in_a_widget] = true    # Let html builders know we're in a widget

    tz = timezone
    tz ||= user_or_group.get_timezone if user_or_group.respond_to?(:get_timezone)

    body = user_or_group.with_a_timezone(tz) do
      if report.rpt_options.fetch_path(:summary, :hide_detail_rows)
        report.rpt_options[:group_limit] = row_count
        report.build_html_rows.join
      else
        report.group = nil                      # Ignore groupings for widgets, unless hiding details
        report.build_html_rows(true)[0..row_count - 1].join # clickable_rows = true
      end
    end

    rows = "<table class='table table-striped table-bordered table-hover'><thead><tr>"
    headers.each { |h| rows << "<th>#{h}</th>" }
    rows << "</tr></thead><tbody>"
    rows << (body.blank? ? "<tr><td colspan='5'>" + _("No records found") + "</td></tr>" : body)
    rows << "</tbody></table>"
  end
end
