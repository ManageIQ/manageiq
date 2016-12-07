class ApplicationHelper::Toolbar::SummaryCenter < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    button(
      :show_summary,
      'fa fa-arrow-left fa-lg',
      proc do
        _('Show %{object_name} Summary') %
          {:object_name => @layout == "cim_base_storage_extent" ? @record.evm_display_name : @record.name}
      end,
      nil,
      :url       => "/show",
      :url_parms => "?id=\#{@record.id}",
      :klass     => ApplicationHelper::Button::ShowSummary),
  ])
end
