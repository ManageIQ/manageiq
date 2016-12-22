class ApplicationHelper::Toolbar::CatalogitemButtonSetCenter < ApplicationHelper::Toolbar::Basic
  button_group('catalogitem_button_set_vmdb', [
    select(
      :catalogitem_button_set_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ab_group_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button Group'),
          t,
          :klass => ApplicationHelper::Button::CatalogItemButtonNew),
        button(
          :ab_button_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Button'),
          t,
          :klass => ApplicationHelper::Button::CatalogItemButtonNew),
        button(
          :ab_group_reorder,
          'pficon pficon-edit fa-lg',
          proc do
            if @view_context.x_active_tree == :ab_tree
              _('Reorder Buttons Groups')
            else
              _('Reorder Buttons and Groups')
            end
          end,
          N_('Reorder'),
          :klass => ApplicationHelper::Button::CatalogItemButton),
      ]
    ),
  ])
end
