class ApplicationHelper::Toolbar::StoragesCenter < ApplicationHelper::Toolbar::Basic
  button_group('storage_vmdb', [
    {
      :buttonSelect => "storage_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "storage_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on the selected \#{ui_lookup(:tables=>\"storages\")}"),
          :url_parms    => "main_div",
          :confirm      => N_("Perform SmartState Analysis on the selected \#{ui_lookup(:tables=>\"storages\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "storage_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove \#{ui_lookup(:tables=>\"storages\")} from the VMDB"),
          :title        => N_("Remove selected \#{ui_lookup(:tables=>\"storages\")} from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected \#{ui_lookup(:tables=>\"storages\")} and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected \#{ui_lookup(:tables=>\"storages\")}?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('storage_policy', [
    {
      :buttonSelect => "storage_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "storage_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for the selected \#{ui_lookup(:tables=>\"storages\")}"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
