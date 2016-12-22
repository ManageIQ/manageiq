class ApplicationHelper::Toolbar::CatalogitemButtonsCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_button_vmdb', [
    select(
      :catalogitem_button_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ab_group_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Button Group'),
          t,
          :klass => ApplicationHelper::Button::CatalogItemButton,
          :url_parms => "main_div"),
        button(
          :ab_button_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button'),
          t,
          :klass => ApplicationHelper::Button::CatalogItemButtonNew),
        button(
          :ab_group_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Button Group'),
          t,
          :klass => ApplicationHelper::Button::CatalogItemButton,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Button Group will be permanently removed!")),
      ]
    ),
  ])
end
