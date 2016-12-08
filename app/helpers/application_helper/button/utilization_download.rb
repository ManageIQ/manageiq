class ApplicationHelper::Button::UtilizationDownload < ApplicationHelper::Button::Basic
  def disabled?
    # to enable the button we
    # a) either have no active tree item (meaning we are in "Planning") and
    #    have planning report data
    return false if @view_context.x_active_tree.nil? &&
                    @sb.fetch_path(:planning, :rpt) && !@sb[:planning][:rpt].table.data.empty?

    # b) we are in the "Utilization" and have trend report and summary
    return false if @sb.fetch_path(:util, :trend_rpt) && @sb.fetch_path(:util, :summary)

    # otherwise the button is off
    @error_message = _('No records found for this report')
    @error_message.present?
  end
end
