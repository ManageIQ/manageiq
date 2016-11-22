class ApplicationHelper::Toolbar::EmsContainersCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_container_vmdb', [
    select(
      :ems_container_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_container_refresh,
          'icon fa fa-refresh fa-lg',
          N_('Refresh Items and Relationships for all Containers Providers'),
          N_('Refresh Items and Relationships'),
          :confirm   => N_("Refresh Items and Relationships related to Containers Providers?"),
          :enabled   => false,
          :url_parms => "main_div",
          :onwhen    => "1+"),
        separator,
        button(
          :ems_container_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add Existing Containers Provider'),
          t,
          :url => "/new"),
        button(
          :ems_container_deployment,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Create Containers Provider'),
          t,
          :data   => {'function' => 'miqCallAngular', 'function-data' => '{ "name": "showListener", "args": [] }'},
          :hidden => ContainerDeploymentService.hide_deployment_wizard?),
        button(
          :ems_container_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Containers Provider to edit'),
          N_('Edit Selected Containers Provider'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :ems_container_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Containers Providers'),
          N_('Remove Containers Providers'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Containers Providers and ALL of their components will be permanently removed!"),
          :enabled   => false,
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
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_container_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Containers Providers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :ems_container_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for these Containers Providers'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(
          :ems_container_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for these Container Managers'),
          N_('Check Compliance of Last Known Configuration'),
          :url_parms => "main_div",
          :confirm   => N_("Initiate Check Compliance of the last known configuration for the selected items?"),
          :enabled   => "false",
          :onwhen    => "1+")
      ]
    ),
  ])
  button_group('ems_container_authentication', [
    select(
      :ems_container_authentication_choice,
      'fa fa-lock fa-lg',
      t = N_('Authentication'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_container_recheck_auth_status,
          'fa fa-search fa-lg',
          N_('Re-check Authentication Status for the selected Containers Providers '),
          N_('Re-check Authentication Status'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
