class ApplicationHelper::Toolbar::CustomButtonsCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_vmdb', [
    select(:custom_button_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:ab_group_edit, 'pficon pficon-edit fa-lg', N_('Edit this Button Group'), N_('Edit this Button Group'),
          :url_parms => "main_div"),
        button(:ab_button_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Button'), N_('Add a new Button')),
        button(:ab_group_delete, 'pficon pficon-delete fa-lg', N_('Remove this Button Group'), N_('Remove this Button Group'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Button Group will be permanently removed.  Are you sure you want to remove the selected Button Group?")),
      ]
    ),
  ])
end
