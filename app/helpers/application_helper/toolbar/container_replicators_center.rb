class ApplicationHelper::Toolbar::ContainerReplicatorsCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_replicator_vmdb', [
    select(
      :container_replicator_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_replicator_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Replicator'),
          t,
          :url => "/new"),
        button(
          :container_replicator_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Replicator to edit'),
          N_('Edit Selected Replicator'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_replicator_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Replicators from the VMDB'),
          N_('Remove Replicators from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Replicators and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Replicators?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
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
      ]
    ),
  ])
end
