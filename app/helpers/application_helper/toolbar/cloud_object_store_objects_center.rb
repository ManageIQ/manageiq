class ApplicationHelper::Toolbar::CloudObjectStoreObjectsCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_object_store_object_policy', [
    select(
      :cloud_object_store_object_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :cloud_object_store_object_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+")
      ]
    )
  ])
end
