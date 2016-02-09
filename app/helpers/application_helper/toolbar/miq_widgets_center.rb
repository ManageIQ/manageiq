class ApplicationHelper::Toolbar::MiqWidgetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_reloading', [
    button(:widget_refresh, 'fa fa-repeat fa-lg', N_('Reload Widgets'), nil    ),
  ])
  button_group('widget_vmdb', [
    select(:widget_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:widget_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a new Widget'), N_('Add a new Widget')),
      ]
    ),
  ])
end
