class ApplicationHelper::Toolbar::CloudVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_policy', [
    select(:cloud_volume_policy_choice, 'fa fa-shield fa-lg', N_('Policy'), N_('Policy'),
      :items     => [
        button(:cloud_volume_tag, 'pficon pficon-edit fa-lg', N_('Edit tags for this #{ui_lookup(:table=>"cloud_volumes")}'), N_('Edit Tags')),
      ]
    ),
  ])
end
