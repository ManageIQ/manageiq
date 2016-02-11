class ApplicationHelper::Toolbar::PersistentVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('persistent_volume_vmdb', [
    select(
      :persistent_volume_vmdb_choice,
      nil,
      t = N_('Configuration'),
      t,
      :image => "vmdb",
      :items => [
        button(
          :persistent_volume_edit,
          nil,
          t = N_('Edit this #{ui_lookup(:table=>"persistent_volume")}'),
          t,
          :image => "edit",
          :url   => "/edit"),
        button(
          :persistent_volume_delete,
          nil,
          t = N_('Remove this #{ui_lookup(:table=>"persistent_volume")} from the VMDB'),
          t,
          :image     => "delete",
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This \#{ui_lookup(:table=>\"persistent_volume\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"persistent_volume\")}?")),
      ]
    ),
  ])
  button_group('persistent_group_policy', [
    select(
      :persistent_volume_policy_choice,
      nil,
      t = N_('Policy'),
      t,
      :image => "policy",
      :items => [
        button(
          :persistent_volume_tag,
          nil,
          N_('Edit Tags for this #{ui_lookup(:table=>"persistent_volume")}'),
          N_('Edit Tags'),
          :image => "tag"),
      ]
    ),
  ])
end
