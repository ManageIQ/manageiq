class ApplicationHelper::Button::MiqReportEdit < ApplicationHelper::Button::Basic
  include ApplicationHelper::Button::Mixins::XActiveTreeMixin

  def visible?
    reports_tree? ? custom_report_info? : true
  end

  private

  def custom_report_info?
    @view_context.active_tab == 'report_info' && @record.rpt_type == 'Custom'
  end
end
