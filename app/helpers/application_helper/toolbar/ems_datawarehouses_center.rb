class ApplicationHelper::Toolbar::EmsDatawarehousesCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_datawarehouse_vmdb', [
    select(
      :ems_datawarehouse_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_datawarehouse_refresh,
          'icon fa fa-refresh fa-lg',
          N_('Refresh Items and Relationships for these Datawarehouse Providers'),
          N_('Refresh Items and Relationships'),
          :confirm   => N_("Refresh Items and Relationships related to these Datawarehouse Providers?"),
          :enabled   => false,
          :url_parms => "main_div",
          :onwhen    => "1+"),
        separator,
        button(
          :ems_datawarehouse_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Datawarehouse Provider'),
          t,
          :url => "/new"),
        button(
          :ems_datawarehouse_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Datawarehouse Providers to edit'),
          N_('Edit Selected Datawarehouse Providers'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :ems_datawarehouse_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Datawarehouse Providers'),
          N_('Remove Datawarehouse Providers'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Datawarehouse Providers and ALL " \
                           "of their components will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_datawarehouse_policy', [
    select(
      :ems_datawarehouse_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_datawarehouse_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Datawarehouse Providers'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('ems_datawarehouse_authentication', [
    select(
      :ems_datawarehouse_authentication_choice,
      'fa fa-lock fa-lg',
      t = N_('Authentication'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ems_datawarehouse_recheck_auth_status,
          'fa fa-search fa-lg',
          N_('Re-check Authentication Status for the selected Datawarehouse Providers'),
          N_('Re-check Authentication Status'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
