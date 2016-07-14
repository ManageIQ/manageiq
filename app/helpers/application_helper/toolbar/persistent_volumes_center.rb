class ApplicationHelper::Toolbar::PersistentVolumesCenter < ApplicationHelper::Toolbar::Basic
  button_group('persistent_volume_vmdb', [
    select(
      :persistent_volume_vmdb_choice,
      nil,
      t = N_('Configuration'),
      t,
      :image => "vmdb",
      :items => [
        button(
          :persistent_volume_new,
          nil,
          t = N_('Add a New Volume'),
          t,
          :image => "new",
          :url   => "/new"),
        button(
          :persistent_volume_edit,
          nil,
          N_('Select a single Volume to edit'),
          N_('Edit Selected Volume'),
          :image     => "edit",
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :persistent_volume_delete,
          nil,
          N_('Remove selected Volumes from the VMDB'),
          N_('Remove Volumes from the VMDB'),
          :image     => "remove",
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Volumes and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Volumes?"),
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('persistent_volume_policy', [
    select(
      :persistent_volume_policy_choice,
      nil,
      t = N_('Policy'),
      t,
      :image   => "policy",
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :persistent_volume_tag,
          nil,
          N_('Edit Tags for this Volumes'),
          N_('Edit Tags'),
          :image     => "tag",
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
