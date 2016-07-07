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
          t = N_('Edit this Volume'),
          t,
          :image => "edit",
          :url   => "/edit"),
        button(
          :persistent_volume_delete,
          nil,
          t = N_('Remove this Volume from the VMDB'),
          t,
          :image     => "delete",
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Volume and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Volume?")),
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
          N_('Edit Tags for this Volume'),
          N_('Edit Tags'),
          :image => "tag"),
      ]
    ),
  ])
end
