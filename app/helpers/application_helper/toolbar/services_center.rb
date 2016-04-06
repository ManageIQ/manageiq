class ApplicationHelper::Toolbar::ServicesCenter < ApplicationHelper::Toolbar::Basic
  button_group('service_vmdb', [
    select(
      :service_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :service_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single service to edit'),
          N_('Edit Selected Service'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1"),
        button(
          :service_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Services from the VMDB'),
          N_('Remove Services from the VMDB'),
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Services and ALL of their components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Services?"),
          :enabled   => false,
          :onwhen    => "1+"),
        separator,
        button(
          :service_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for the selected Services'),
          N_('Set Ownership'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('service_policy', [
    select(
      :service_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :service_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit tags for the selected Items'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
  button_group('service_lifecycle', [
    select(
      :service_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :service_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for the selected items'),
          N_('Set Retirement Dates'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
        button(
          :service_retire_now,
          'fa fa-clock-o fa-lg',
          N_('Retire the selected items'),
          N_('Retire selected items'),
          :url_parms => "main_div",
          :confirm   => N_("Retire the selected items?"),
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
