class ApplicationHelper::Toolbar::PersistentVolumeCenter < ApplicationHelper::Toolbar::Basic
  button_group('persistent_volume_vmdb', [
    {
      :buttonSelect => "persistent_volume_vmdb_choice",
      :image        => "vmdb",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "persistent_volume_edit",
          :image        => "edit",
          :text         => N_("Edit this \#{ui_lookup(:table=>\"persistent_volume\")}"),
          :title        => N_("Edit this \#{ui_lookup(:table=>\"persistent_volume\")}"),
          :url          => "/edit",
        },
        {
          :button       => "persistent_volume_delete",
          :image        => "delete",
          :text         => N_("Remove this \#{ui_lookup(:table=>\"persistent_volume\")} from the VMDB"),
          :title        => N_("Remove this \#{ui_lookup(:table=>\"persistent_volume\")} from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This \#{ui_lookup(:table=>\"persistent_volume\")} and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this \#{ui_lookup(:table=>\"persistent_volume\")}?"),
        },
      ]
    },
  ])
  button_group('persistent_group_policy', [
    {
      :buttonSelect => "persistent_volume_policy_choice",
      :image        => "policy",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "persistent_volume_tag",
          :image        => "tag",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"persistent_volume\")}"),
        },
      ]
    },
  ])
end
