class ApplicationHelper::ToolbarButtons
  def self.button_class(button_id)
    case button_id
    when 'chargeback_download_pdf', 'download_pdf', 'download_view',
         'drift_pdf', 'miq_capacity_download_pdf', 'render_report_pdf',
         'timeline_pdf', 'vm_download_pdf'
      ApplicationHelper::Button::Pdf
    when 'chargeback_report_only'
      ApplicationHelper::Button::ChargebackReportOnly
    when /^orchestration_template_(edit|remove)$/
      ApplicationHelper::Button::OrchestrationTemplateEditRemove
    when 'history_choice'
      ApplicationHelper::Button::HistoryChoice
    when /^history_(\d+)$/
      ApplicationHelper::Button::HistoryItem
    when 'chargeback_download_choice'
      ApplicationHelper::Button::ChargebackDownloadChoice
    when /^old_dialogs_(edit|delete)$/
      ApplicationHelper::Button::OldDialogsEditDelete
    when 'collect_logs', 'collect_current_logs', 'zone_collect_logs', 'zone_collect_current_logs'
      ApplicationHelper::Button::CollectLogs
    when 'view_grid', 'view_tile', 'view_list'
      ApplicationHelper::Button::View
    else
      ApplicationHelper::Button::Basic
    end
  end

  def self.button(view_context, view_binding, instance_data, props)
    button_class = button_class(props['child_id'] || props['id'])
    button = button_class.new(view_context, view_binding, instance_data, props)
    button
  end
end
