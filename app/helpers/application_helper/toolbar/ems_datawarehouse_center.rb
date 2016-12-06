class ApplicationHelper::Toolbar::EmsDatawarehouseCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_datawarehouse_vmdb', [
    select(
      :ems_datawarehouse_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_datawarehouse_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh items and relationships related to this Datawarehouse Provider'),
          N_('Refresh items and relationships'),
          :confirm => N_("Refresh items and relationships related to this Datawarehouse Provider?")),
        separator,
        button(
          :ems_datawarehouse_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Datawarehouse Provider'),
          t),
        button(
          :ems_datawarehouse_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Datawarehouse Provider'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Datawarehouse Provider and ALL" \
                           " of its components will be permanently removed!")),
      ]
    ),
  ])
  button_group('ems_datawarehouse_monitoring', [
    select(
      :ems_datawarehouser_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_datawarehouse_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Datawarehouse Provider'),
          N_('Timelines'),
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('ems_datawarehouse_policy', [
    select(
      :ems_datawarehouse_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_datawarehouse_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Datawarehouse Provider'),
          N_('Edit Tags')),
      ]
    ),
  ])
  button_group('ems_datawarehouse_authentication', [
    select(
      :ems_datawarehouse_authentication_choice,
      'fa fa-lock fa-lg',
      t = N_('Authentication'),
      t,
      :items => [
        button(
          :ems_datawarehouse_recheck_auth_status,
          'fa fa-search fa-lg',
          proc do
            _("Re-check Authentication Status for this %{warehouse}") % {:warehouse => ui_lookup(:table=>'ems_datawarehouse')}
          end,
          N_('Re-check Authentication Status'),
          :klass => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :authentication_status}),
      ]
    ),
  ])
end
