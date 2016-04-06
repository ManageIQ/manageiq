class ApplicationHelper::Toolbar::OntapLogicalDisksCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_logical_disk_policy', [
    select(
      :ontap_logical_disk_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :ontap_logical_disk_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected Logical Disks'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
