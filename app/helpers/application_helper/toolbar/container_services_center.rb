class ApplicationHelper::Toolbar::ContainerServicesCenter < ApplicationHelper::Toolbar::Basic
  button_group('container_service_policy', [
    select(
      :container_service_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :enabled => false,
      :onwhen  => "1+",
      :items   => [
        button(
          :container_service_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for these Services'),
          N_('Edit Tags'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+"),
      ]
    ),
  ])
end
