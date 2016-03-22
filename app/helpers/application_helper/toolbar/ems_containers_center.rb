class ApplicationHelper::Toolbar::EmsContainersCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_vmdb', [
    select(
      :ems_container_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_container_deployment,
          'icon fa fa-plus fa-lg',
          t = N_('Deploy a New #{ui_lookup(:table=>"ems_container")}'),
          t,
          :url => "/deployment"),
        button(
          :ems_container_refresh,
          'icon fa fa-refresh fa-lg',
          N_('Refresh Items and Relationships for all #{ui_lookup(:table=>"ems_containers")}'),
          N_('Refresh Items and Relationships'),
          :confirm   => N_("Refresh Items and Relationships related to  \#{ui_lookup(:table=>\"ems_containers\")}?"),
          :enabled   => "false",
          :url_parms => "main_div",
          :onwhen    => "1+"),
        separator,
        button(
          :ems_container_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New #{ui_lookup(:table=>"ems_container")}'),
          t,
          :url => "/new"),
        button(
          :ems_container_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single #{ui_lookup(:table=>"ems_container")} to edit'),
          N_('Edit Selected #{ui_lookup(:table=>"ems_container")}'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :ems_container_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected #{ui_lookup(:tables=>"ems_containers")} from the VMDB'),
          N_('Remove #{ui_lookup(:tables=>"ems_containers")} from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected \#{ui_lookup(:tables=>\"ems_containers\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"ems_containers\")}?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_container_policy', [
    select(
      :ems_container_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"ems_container")}'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
