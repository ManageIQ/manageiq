class ApplicationHelper::Toolbar::ContainerImageCenter < ApplicationHelper::Toolbar::Basic
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
          N_('Perform SmartState Analysis on this item'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this item?")),
      ]
    ),
  ])
  button_group('container_image_policy', [
    select(
      :container_image_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_image_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Image'),
          N_('Edit Tags')),
        button(
          :container_image_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Image'),
          N_('Manage Policies')),
        button(
          :container_image_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this item'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this item?"))
      ]
    ),
  ])
end
