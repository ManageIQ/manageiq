class ApplicationHelper::Toolbar::HostCloudServicesCenter < ApplicationHelper::Toolbar::Basic
  button_group('host_cloud_services_vmdb', [select(
    :host_cloud_services_choice,
    'fa fa-cog fa-lg',
    t = N_('Cloud Service Configuration'),
    t,
    :items => [
      button(
        :host_cloud_service_scheduling_toggle,
        'pficon pficon-edit fa-lg',
        N_('Toggle Scheduling'),
        N_('Toggle Scheduling'),
        :confirm   => N_("Toggle Scheduling for this Cloud Service?"),
        :url_parms => "main_div",
        :enabled   => false,
        :onwhen    => "1+"),
    ]),
  ])
end
