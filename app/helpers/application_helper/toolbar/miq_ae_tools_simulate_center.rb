class ApplicationHelper::Toolbar::MiqAeToolsSimulateCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_tools_vmdb', [
    button(
      :ae_copy_simulate,
      'fa fa-files-o fa-lg',
      N_('Copy object details for use in a Button'),
      N_('Copy'),
      :url       => "resolve",
      :url_parms => "?button=copy"),
  ])
end
