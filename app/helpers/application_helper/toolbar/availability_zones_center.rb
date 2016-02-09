class ApplicationHelper::Toolbar::AvailabilityZonesCenter < ApplicationHelper::Toolbar::Basic
  button_group('availability_zone_policy', [
    {
      :buttonSelect => "availability_zone_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "availability_zone_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected Availability Zones"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
