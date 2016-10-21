class ApplicationHelper::Toolbar::SecurityGroupCenter < ApplicationHelper::Toolbar::Basic
  button_group(
    'security_group_vmdb',
    [
      select(
        :security_group_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :items => [
          button(
            :security_group_edit,
            'pficon pficon-edit fa-lg',
            t = N_('Edit this Security Group'),
            t,
            :url_parms => 'main_div',
            :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
            :options   => {:feature => :update_security_group}
          ),
          button(
            :security_group_delete,
            'pficon pficon-delete fa-lg',
            t = N_('Delete this Security Group'),
            t,
            :url_parms => 'main_div',
            :confirm   => N_('Warning: This Security Group and ALL of its components will be removed!'),
            :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
            :options   => {:feature => :delete_security_group}
          )
        ]
      )
    ]
  )
  button_group('security_group_policy', [
    select(
      :security_group_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :security_group_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Security Group'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
