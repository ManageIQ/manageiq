class ApplicationHelper::Toolbar::CloudSubnetCenter < ApplicationHelper::Toolbar::Basic
  button_group('cloud_subnet_vmdb', [
    select(
      :cloud_subnet_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :cloud_subnet_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Cloud Subnet'),
          t,
          :url_parms => 'main_div',
          :klass => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :update}
        ),
        button(
          :cloud_subnet_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete this Cloud Subnet'),
          t,
          :url_parms => 'main_div',
          :confirm   => N_('Warning: This Cloud Subnet and ALL of its components will be removed!'),
          :klass => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :delete}
        ),
      ]
    )])

  button_group('cloud_subnet_policy', [
    select(
      :cloud_subnet_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :cloud_subnet_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Cloud Subnet'),
          N_('Edit Tags')),
      ]
    ),
  ])
end
