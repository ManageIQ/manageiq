class ApplicationHelper::Toolbar::PersistentVolumesCenter < ApplicationHelper::Toolbar::Basic
  button_group('persistent_volume_vmdb', [
    {
      :buttonSelect => "persistent_volume_vmdb_choice",
      :image        => "vmdb",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "persistent_volume_new",
          :image        => "new",
          :url          => "/new",
          :text         => N_("Add a New \#{ui_lookup(:table=>\"persistent_volume\")}"),
          :title        => N_("Add a New \#{ui_lookup(:table=>\"persistent_volume\")}"),
        },
        {
          :button       => "persistent_volume_edit",
          :image        => "edit",
          :text         => N_("Edit Selected \#{ui_lookup(:table=>\"persistent_volume\")}"),
          :title        => N_("Select a single \#{ui_lookup(:table=>\"persistent_volume\")} to edit"),
          :url_parms    => "main_div",
          :onwhen       => "1",
        },
        {
          :button       => "persistent_volume_delete",
          :image        => "remove",
          :text         => N_("Remove \#{ui_lookup(:tables=>\"persistent_volumes\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"persistent_volumes\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"persistent_volumes\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"persistent_volumes\")}?"),
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('persistent_volume_policy', [
    {
      :buttonSelect => "persistent_volume_policy_choice",
      :image        => "policy",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "persistent_volume_tag",
          :image        => "tag",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this \#{ui_lookup(:table=>\"persistent_volumes\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
