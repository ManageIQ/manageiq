class ApplicationHelper::Toolbar::CustomizationTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('customization_template_vmdb', [
    {
      :buttonSelect => "pxe_server_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "customization_template_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Customization Template"),
          :title        => N_("Add a New Customization Template"),
        },
        {
          :button       => "customization_template_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy Selected Customization Templates"),
          :title        => N_("Select a single Customization Templates to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "customization_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Customization Templates"),
          :title        => N_("Select a single Customization Templates to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "customization_template_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Customization Templates from the VMDB"),
          :title        => N_("Remove selected Customization Templates from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Customization Templates will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Customization Templates?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
