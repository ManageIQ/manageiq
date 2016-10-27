class ApplicationHelper::Toolbar::CustomButtonsCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_vmdb', [
    select(
      :custom_button_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ab_group_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Button Group'),
          t,
          :url_parms => "main_div",
          :klass     => ApplicationHelper::Button::AbGroupEdit),
        button(
          :ab_button_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button'),
          t,
          :klass => ApplicationHelper::Button::AbButtonNew),
        button(
          :ab_group_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Button Group'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Button Group will be permanently removed!"),
          :klass     => ApplicationHelper::Button::AbGroupEdit),
      ]
    ),
  ])
end
