class ApplicationHelper::Toolbar::ServicetemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_vmdb', [
    {
      :buttonSelect => "catalogitem_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "atomic_catalogitem_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Catalog Item"),
          :title        => N_("Add a New Catalog Item"),
        },
        {
          :button       => "catalogitem_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Catalog Bundle"),
          :title        => N_("Add a New Catalog Bundle"),
        },
        {
          :button       => "catalogitem_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Item"),
          :title        => N_("Select a single Item to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "catalogitem_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Items from the VMDB"),
          :title        => N_("Remove selected Items from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
  button_group('catalogitem_policy', [
    {
      :buttonSelect => "catalogitem_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :enabled      => "false",
      :onwhen       => "1+",
      :items => [
        {
          :button       => "catalogitem_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit tags for the selected Items"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
