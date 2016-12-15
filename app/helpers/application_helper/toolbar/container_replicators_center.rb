class ApplicationHelper::Toolbar::ContainerReplicatorsCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_replicator_policy', [
    select(
      :container_replicator_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_replicator_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Replicators'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :container_replicator_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for these Replicators'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :container_replicator_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for these Replicators'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+")
      ]
    ),
  ])
end
