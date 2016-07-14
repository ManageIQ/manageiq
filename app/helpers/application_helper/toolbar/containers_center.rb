class ApplicationHelper::Toolbar::ContainersCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_vmdb', [
    select(
      :container_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Container'),
          t,
          :url => "/new"),
        button(
          :container_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Container to edit'),
          N_('Edit Selected Container'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Containers from the VMDB'),
          N_('Remove Containers from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Containers and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Containers?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_policy', [
    select(
      :container_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for selected Containers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
