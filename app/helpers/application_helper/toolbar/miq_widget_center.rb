class ApplicationHelper::Toolbar::MiqWidgetCenter < ApplicationHelper::Toolbar::Basic
  button_group('widget_vmdb', [
    select(:widget_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:widget_edit, 'pficon pficon-edit fa-lg', N_('Edit this Widget'), N_('Edit this Widget')),
        button(:widget_copy, 'fa fa-files-o fa-lg', N_('Copy this Widget'), N_('Copy this Widget')),
        button(:widget_delete, 'pficon pficon-delete fa-lg', N_('Delete this Widget from the Database'), N_('Delete this Widget from the Database'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Widget and ALL of its components will be permanently removed from the VMDB.  Are you sure you want to delete this Widget?")),
        separator,
        button(:widget_generate_content, 'fa fa-cog fa-lg', N_('Generate Widget content now'), N_('Generate Widget content now'),
          :confirm   => N_("Are you sure you want initiate content generation for this Widget now?")),
      ]
    ),
  ])
end
