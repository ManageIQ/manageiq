class ApplicationHelper::Toolbar::CustomizationTemplatesCenter < ApplicationHelper::Toolbar::Basic
  button_group('customization_template_vmdb', [
    select(
      :pxe_server_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :customization_template_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Customization Template'),
          t),
        button(
          :customization_template_copy,
          'fa fa-files-o fa-lg',
          N_('Select a single Customization Templates to copy'),
          N_('Copy Selected Customization Templates'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :customization_template_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Customization Templates to edit'),
          N_('Edit Selected Customization Templates'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(
          :customization_template_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Customization Templates from the VMDB'),
          N_('Remove Customization Templates from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Customization Templates will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Customization Templates?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
