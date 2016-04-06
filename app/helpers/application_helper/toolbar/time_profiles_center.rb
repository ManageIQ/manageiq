class ApplicationHelper::Toolbar::TimeProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    select(
      :miq_schedule_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :timeprofile_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Time Profile'),
          t,
          :url => "/timeprofile_new"),
        button(
          :tp_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Time Profile to edit'),
          N_('Edit selected Time Profile'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :tp_copy,
          'fa fa-files-o fa-lg',
          N_('Select a single Time Profile to copy'),
          N_('Copy selected Time Profile'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :tp_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete selected Time Profiles'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Time Profiles will be permanently removed from the VMDB. Are you sure you want to delete the selected Time Profiles?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
