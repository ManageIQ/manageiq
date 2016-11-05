module TreeNode
  class MiqReportResult < Node
    set_attribute(:image) do
      case @object.status.downcase
      when 'error'
        '100/report_result_error.png'
      when 'finished'
        '100/report_result_completed.png'
      when 'running'
        '100/report_result_running.png'
      when 'queued'
        '100/report_result_queued.png'
      else
        '100/report_result.png'
      end
    end

    set_attributes(:title, :tooltip, :expand) do
      expand = nil
      if @object.last_run_on.nil? && %w(queued running).include?(@object.status.downcase)
        title   = _('Generating Report')
        tooltip = _('Generating Report for - %{report_name}') % {:report_name => @object.name}
      elsif @object.last_run_on.nil? && @object.status.downcase == 'error'
        title   = _('Error Generating Report')
        tooltip = _('Error Generating Report for %{report_name}') % {:report_name => @object.name}
        expand  = !!@options[:open_all]
      else
        title   = format_timezone(@object.last_run_on, Time.zone, 'gtl')
        tooltip = nil
      end
      [title, tooltip, expand]
    end
  end
end
