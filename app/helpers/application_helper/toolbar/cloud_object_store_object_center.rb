class ApplicationHelper::Toolbar::CloudObjectStoreObjectCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_object_store_object_policy', [
    select(
      :cloud_object_store_object_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_object_store_object_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for this #{ui_lookup(:table=>"cloud_object")}'),
          N_('Edit Tags'))
      ]
    )
  ])
end
