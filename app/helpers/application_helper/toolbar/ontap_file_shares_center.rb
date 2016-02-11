class ApplicationHelper::Toolbar::OntapFileSharesCenter < ApplicationHelper::Toolbar::Basic
  button_group('ontap_file_share_policy', [
    select(
      :ontap_file_share_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :ontap_file_share_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected File Shares'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
