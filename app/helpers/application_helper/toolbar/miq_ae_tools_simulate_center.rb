class ApplicationHelper::Toolbar::MiqAeToolsSimulateCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_tools_vmdb', [
    {
      :button       => "ae_copy_simulate",
      :icon         => "fa fa-files-o fa-lg",
      :text         => N_("Copy"),
      :title        => N_("Copy object details for use in a Button"),
      :url          => "resolve",
      :url_parms    => "?button=copy",
    },
  ])
end
