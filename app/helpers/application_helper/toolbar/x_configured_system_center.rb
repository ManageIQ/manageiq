class ApplicationHelper::Toolbar::XConfiguredSystemCenter < ApplicationHelper::Toolbar::Basic
  button_group('record_summary', [
    select(
      :provider_foreman_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :enabled => "true",
      :items   => [
        button(
          :configured_system_provision,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Provision Configured System'),
          t,
          :url       => "provision",
          :url_parms => "main_div",
          :enabled   => "true"),
      ]
    ),
    select(
      :provider_foreman_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "true",
      :items   => [
        button(
          :configured_system_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Configured System'),
          N_('Edit Tags'),
          :url       => "tagging",
          :url_parms => "main_div",
          :enabled   => "true"),
      ]
    ),
  ])
end
