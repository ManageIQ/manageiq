class ApplicationHelper::Toolbar::CloudVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_volume_policy', [
    {
      :buttonSelect => "cloud_volume_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "cloud_volume_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for this \#{ui_lookup(:table=>\"cloud_volumes\")}"),
        },
      ]
    },
  ])
end
