module ApplicationHelper::Toolbar::ConfiguredSystem::LifecycleMixin
  def included(included_class)
    button_group('provider_foreman_lifecycle', [
      select(
        :provider_foreman_lifecycle_choice,
        'fa fa-recycle fa-lg',
        t = N_('Lifecycle'),
        t,
        :enabled => true,
        :items   => [
          included_class.button(
            :configured_system_provision,
            'pficon pficon-add-circle-o fa-lg',
            t = N_('Provision Configured Systems'),
            t,
            :url       => "provision",
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1+"),
        ]
      ),
    ])
  end
end
