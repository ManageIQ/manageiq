class ApplicationHelper::Toolbar::SummaryCenterRestful < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    button(
      :show_summary,
      'fa fa-arrow-left fa-lg',
      N_('Show #{@layout == "cim_base_storage_extent" ? @record.evm_display_name : @record.name} Summary'),
      nil,
      :url       => "/",
      :url_parms => "?id=\#{@record.id}"),
  ])
end
