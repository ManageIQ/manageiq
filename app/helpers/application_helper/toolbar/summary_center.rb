class ApplicationHelper::Toolbar::SummaryCenter < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    {
      :button       => "show_summary",
      :icon         => "fa fa-arrow-left fa-lg",
      :title        => N_("Show \#{@layout == \"cim_base_storage_extent\" ? @record.evm_display_name : @record.name} Summary"),
      :url          => "/show",
      :url_parms    => "?id=\#{@record.id}",
    },
  ])
end
