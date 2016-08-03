class ApplicationHelper::Toolbar::ConfigurationJobCenter < ApplicationHelper::Toolbar::Basic
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
          t = N_('Remove this Job'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Job and ALL of its components will be permanently removed!")),
      ]
    ),
  ])
  button_group('configuration_job_policy', [
    select(
      :configuration_job_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :configuration_job_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Job'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
