module ApplicationHelper::Toolbar::ConfigurationScripts::PolicyMixin
  def self.included(included_class)
    included_class.button_group('provider_foreman_policy',
                                [included_class.select(:provider_foreman_policy_choice,
                                                       'fa fa-shield fa-lg',
                                                       t = N_('Policy'),
                                                       t,
                                                       :items => [
                                                         included_class.button(
                                                           :configuration_script_tag,
                                                           'pficon pficon-edit fa-lg',
                                                           N_('Edit Tags for this Job Template'),
                                                           N_('Edit Tags'),
                                                           :url       => "tagging",
                                                           :url_parms => "main_div",
                                                           :enabled   => false,
                                                           :onwhen    => "1+"),
                                                       ]),
                                ])
  end
end
