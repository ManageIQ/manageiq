class ApplicationHelper::Toolbar::ContainerNodesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_node_vmdb', [
    select(
      :container_node_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_node_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Node'),
          t,
          :url => "/new"),
        button(
          :container_node_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Node to edit'),
          N_('Edit Selected Node'),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :container_node_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Nodes from the VMDB'),
          N_('Remove Nodes from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Nodes and ALL of their components will be permanently removed!"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_node_policy', [
    select(
      :container_node_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_node_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Nodes'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :container_node_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for these Nodes'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :container_node_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for these Nodes'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+")
      ]
    ),
  ])
end
