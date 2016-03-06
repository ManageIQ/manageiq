class ApplicationHelper::Toolbar::ContainerImagesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_image_vmdb', [
    select(
      :container_image_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_image_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on the selected items'),
          N_('Perform SmartState Analysis'),
          :url_parms => "main_div",
          :confirm   => N_("Perform SmartState Analysis on the selected items?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('container_image_policy', [
    select(
      :container_image_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_image_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for the selected items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :container_image_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this #{ui_lookup(:table=>"container_images")}'),
          N_('Manage Policies'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
