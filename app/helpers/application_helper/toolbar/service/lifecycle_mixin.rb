module ApplicationHelper::Toolbar::Service::LifecycleMixin
  def self.included(included_class)
    included_class.button_group('service_lifecycle', [
      included_class.select(
        :service_lifecycle_choice,
        'fa fa-recycle fa-lg',
        t = N_('Lifecycle'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          included_class.button(
            :service_retire,
            'fa fa-clock-o fa-lg',
            N_('Set Retirement Dates for the selected items'),
            N_('Set Retirement Dates'),
            :enabled   => false,
            :url_parms => "main_div",
            :onwhen    => "1+"),
          included_class.button(
            :service_retire_now,
            'fa fa-clock-o fa-lg',
            N_('Retire the selected items'),
            N_('Retire selected items'),
            :url_parms => "main_div",
            :confirm   => N_("Retire the selected items?"),
            :enabled   => false,
            :onwhen    => "1+"),
        ]),
    ])
  end
end
