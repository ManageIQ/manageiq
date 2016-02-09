class ApplicationHelper::Toolbar::CustomizationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('customization_template_vmdb', [
    select(:customization_template_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:customization_template_copy, 'fa fa-files-o fa-lg', N_('Copy this Customization Template'), N_('Copy this Customization Template')),
        button(:customization_template_edit, 'pficon pficon-edit fa-lg', N_('Edit this Customization Template'), N_('Edit this Customization Template')),
        button(:customization_template_delete, 'pficon pficon-delete fa-lg', N_('Remove this Customization Template from the VMDB'), N_('Remove this Customization Template from the VMDB'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Customization Template will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Customization Template?")),
      ]
    ),
  ])
end
