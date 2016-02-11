class ApplicationHelper::Toolbar::CustomButtonCenter < ApplicationHelper::Toolbar::Basic
  button_group('custom_button_vmdb', [
    select(
      :custom_button_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ab_button_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Button'),
          t,
          :url_parms => "main_div"),
        button(
          :ab_button_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Button'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Button will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Button?")),
        separator,
        button(
          :ab_button_simulate,
          'fa fa-play-circle-o fa-lg',
          N_('Simulate using Button details'),
          N_('Simulate'),
          :url       => "resolve",
          :url_parms => "?button=simulate"),
      ]
    ),
  ])
end
