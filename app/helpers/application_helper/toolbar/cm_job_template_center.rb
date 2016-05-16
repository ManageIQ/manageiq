class ApplicationHelper::Toolbar::CmJobTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('cm_job_template_vmdb', [
                                       select(
                                         :cm_job_template_vmdb_choice,
                                         'fa fa-cog fa-lg',
                                         t = N_('Configuration'),
                                         t,
                                         :items => [
                                           button(
                                             :jobtemplate_service_dialog,
                                             'pficon pficon-add-circle-o fa-lg',
                                             t = N_('Create Service Dialog from this Job Template'),
                                             t),
                                         ]
                                       ),
                                     ])
end
