class ApplicationHelper::Toolbar::XConfigurationScriptCenter < ApplicationHelper::Toolbar::Basic
  button_group('configuration_script_vmdb', [
    select(
      :configuration_script_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :configscript_service_dialog,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Create Service Dialog from this Job Template'),
          t),
                ]
    ),
    select(
      :provider_foreman_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => true,
      :items   => [
        button(
          :configuration_script_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Job Template'),
          N_('Edit Tags'),
          :url       => "tagging",
          :url_parms => "main_div",
          :enabled   => true),
      ]
    ),
  ])
end
