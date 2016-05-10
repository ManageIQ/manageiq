class ApplicationHelper::Toolbar::XCmJobTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('provider_vmdb', [
                                select(
                                  :provider_vmdb_choice,
                                  'fa fa-cog fa-lg',
                                  t = N_('Configuration'),
                                  t,
                                  :enabled => true,
                                  :items   => [
                                    button(
                                      :cm_job_template_service_dialog,
                                      'pficon pficon-add-circle-o fa-lg',
                                      N_('Create Service Dialog from this Job Template'),
                                      N_('Create Service Dialog from this Job Template'),
                                      :url => "service_dialog",
                                      :enabled   => false,
                                      :onwhen    => "1+")
                                  ]
                                ),
                              ])
  button_group('provider_foreman_policy', [
                                          select(
                                            :provider_foreman_policy_choice,
                                            'fa fa-shield fa-lg',
                                            t = N_('Policy'),
                                            t,
                                            :items => [
                                              button(
                                                :cm_job_templates_tag,
                                                'pficon pficon-edit fa-lg',
                                                N_('Edit Tags for this Job Template'),
                                                N_('Edit Tags'),
                                                :url       => "tagging",
                                                :url_parms => "main_div",
                                                :enabled   => false,
                                                :onwhen    => "1+"),
                                            ]
                                          ),
                                        ])
end
