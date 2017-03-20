module ApplicationHelper::Toolbar::Service::PolicyMixin
  def self.included(included_class)
    included_class.button_group('service_policy', [
      included_class.select(
        :service_policy_choice,
        'fa fa-shield fa-lg',
        t = N_('Policy'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          included_class.button(
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
  end
end
