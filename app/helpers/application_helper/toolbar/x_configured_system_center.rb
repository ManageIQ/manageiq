class ApplicationHelper::Toolbar::XConfiguredSystemCenter < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    select(:provider_foreman_lifecycle_choice, 'fa fa-recycle fa-lg', N_('Lifecycle'), N_('Lifecycle'),
      :enabled   => "true",
      :items     => [
        button(:configured_system_provision, 'pficon pficon-add-circle-o fa-lg', N_('Provision Configured System'), N_('Provision Configured System'),
          :url       => "provision",
          :url_parms => "main_div",
          :enabled   => "true"),
      ]
    ),
    select(:provider_foreman_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :enabled   => "true",
      :items     => [
        button(:configured_system_tag, 'pficon pficon-edit fa-lg', N_('Edit Tags for this Configured System'), N_('Edit Tags'),
          :url       => "tagging",
          :url_parms => "main_div",
          :enabled   => "true"),
      ]
    ),
  ])
end
