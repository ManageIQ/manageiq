class ApplicationHelper::Toolbar::MiqWidgetCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_vmdb', [
    select(
      :widget_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :widget_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Widget'),
          t),
        button(
          :widget_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Widget'),
          t),
        button(
          :widget_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Widget from the Database'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Widget and ALL of its components will be permanently removed!")),
        separator,
        button(
          :widget_generate_content,
          'fa fa-cog fa-lg',
          t = N_('Generate Widget content now'),
          t,
          :confirm => N_("Are you sure you want initiate content generation for this Widget now?"),
          :klass   => ApplicationHelper::Button::WidgetGenerateContent),
      ]
    ),
  ])
end
