class ApplicationHelper::Toolbar::ServicetemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_vmdb', [
    {
      :buttonSelect => "catalogitem_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :onwhen       => "1+",
      :items => [
        {
          :button       => "ab_group_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Button Group"),
          :title        => N_("Add a new Button Group"),
        },
        {
          :button       => "ab_button_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Button"),
          :title        => N_("Add a new Button"),
        },
        {
          :button       => "catalogitem_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Item"),
          :title        => N_("Edit this Item"),
          :url_parms    => "main_div",
        },
        {
          :button       => "catalogitem_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Item from the VMDB"),
          :title        => N_("Remove this Item from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Catalog Items and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Catalog Item?"),
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
      :items => [
        {
          :button       => "catalogitem_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :url_parms    => "main_div",
          :title        => N_("Edit Tags for this Catalog Item"),
        },
      ]
    },
  ])
end
