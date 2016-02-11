class ApplicationHelper::Toolbar::ServiceCenter < ApplicationHelper::Toolbar::Basic
  button_group('service_vmdb', [
    select(
      :service_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :onwhen => "1+",
      :items  => [
        button(
          :service_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Service'),
          t),
        button(
          :service_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Service from the VMDB'),
          N_('Remove Service from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: This Service and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Service?")),
        separator,
        button(
          :service_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for this Service'),
          N_('Set Ownership')),
        separator,
        button(
          :service_reconfigure,
          'pficon pficon-edit fa-lg',
          N_('Reconfigure the options of this Service'),
          N_('Reconfigure this Service')),
      ]
    ),
  ])
  button_group('service_policy', [
    select(
      :service_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :service_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Service'),
          N_('Edit Tags'),
          :url_parms => "main_div"),
      ]
    ),
  ])
  button_group('service_lifecycle', [
    select(
      :service_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :service_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for this Service'),
          N_('Set Retirement Date')),
        button(
          :service_retire_now,
          'fa fa-clock-o fa-lg',
          t = N_('Retire this Service'),
          t,
          :confirm => N_("Retire this Service?")),
      ]
    ),
  ])
end
