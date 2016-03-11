class ApplicationHelper::Toolbar::ContainerBuildCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_build_vmdb', [
    select(
      :container_build_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :container_build_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this item'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this item?")),
      ]
    ),
  ])
  button_group('container_build_policy', [
    select(
      :container_build_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :container_build_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this #{ui_lookup(:table=>"container_build")}'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
