class ApplicationHelper::Toolbar::MiqWidgetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_reloading', [
    button(
      :widget_refresh,
      'fa fa-repeat fa-lg',
      N_('Reload Widgets'),
      nil),
  ])
  button_group('widget_vmdb', [
    select(
      :widget_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :widget_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Widget'),
          t,
          :klass => ApplicationHelper::Button::WidgetNew),
      ]
    ),
  ])
end
