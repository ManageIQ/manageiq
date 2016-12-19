class ApplicationHelper::Toolbar::FloatingIpCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'floating_ip_vmdb',
    [
      select(
        :floating_ip_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :floating_ip_edit,
            'pficon pficon-edit fa-lg',
            t = N_('Manage the port association of this Floating'),
            t,
            :url_parms => 'main_div',
            :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
            :options   => {:feature => :update}
          ),
          button(
            :floating_ip_delete,
            'pficon pficon-delete fa-lg',
            t = N_('Delete this Floating IP'),
            t,
            :url_parms => 'main_div',
            :confirm   => N_('Warning: This Floating IP and ALL of its components will be removed!'),
            :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
            :options   => {:feature => :delete}
          )
        ]
      )
    ]
  )
  button_group(
    'floating_ip_policy',
    [
      select(
        :floating_ip_policy_choice,
        'fa fa-shield fa-lg',
        t = N_('Policy'),
        t,
        :items => [
          button(
            :floating_ip_tag,
            'pficon pficon-edit fa-lg',
            N_('Edit Tags for this Floating IP'),
            N_('Edit Tags')
          )
        ]
      )
    ]
  )
end
