class ApplicationHelper::Toolbar::AvailabilityZonesCenter < ApplicationHelper::Toolbar::Basic
  button_group('availability_zone_policy', [
    select(
      :availability_zone_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => "false",
      :onwhen  => "1+",
      :items   => [
        button(
          :availability_zone_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected Availability Zones'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
