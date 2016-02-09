class ApplicationHelper::Toolbar::CustomizationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('customization_template_vmdb', [
    {
      :buttonSelect => "customization_template_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "customization_template_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Customization Template"),
          :title        => N_("Copy this Customization Template"),
        },
        {
          :button       => "customization_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Customization Template"),
          :title        => N_("Edit this Customization Template"),
        },
        {
          :button       => "customization_template_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Customization Template from the VMDB"),
          :title        => N_("Remove this Customization Template from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Customization Template will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Customization Template?"),
        },
      ]
    },
  ])
end
