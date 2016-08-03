class ApplicationHelper::Toolbar::ConfigurationJobsCenter < ApplicationHelper::Toolbar::Basic
  button_group('configuration_job_vmdb', [
    select(
      :configuration_job_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :configuration_job_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Jobs'),
          N_('Remove Jobs'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Jobs and ALL of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('configuration_job_policy', [
    select(
      :configuration_job_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :configuration_job_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Jobs'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
