class ApplicationHelper::Toolbar::EmsCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('ems_cloud_vmdb', [
    button(
      :refresh_server_summary,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
    select(
      :ems_cloud_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :ems_cloud_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this Cloud Provider'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Cloud Provider?")),
        separator,
        button(
          :ems_cloud_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Cloud Provider'),
          t,
          :full_path => "<%= edit_ems_cloud_path(@ems) %>"),
        button(
          :ems_cloud_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Cloud Provider'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Cloud Provider and ALL of its components will be permanently removed!")),
        separator,
        button(
          :arbitration_profile_new,
          'pficon pficon-edit fa-lg',
          t = N_('Add a new Arbitration Profile to this Cloud Provider'),
          t),
      ]
    ),
  ])
  button_group('ems_cloud_policy', [
    select(
      :ems_cloud_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :ems_cloud_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Cloud Provider'),
          N_('Manage Policies')),
        button(
          :ems_cloud_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Cloud Provider'),
          N_('Edit Tags')),
        button(
          :ems_cloud_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Cloud Manager'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this item?")),
      ]
    ),
  ])
  button_group('ems_cloud_monitoring', [
    select(
      :ems_cloud_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :ems_cloud_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Cloud Provider'),
          N_('Timelines'),
          :klass     => ApplicationHelper::Button::EmsTimeline,
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('ems_cloud_authentication', [
    select(
      :ems_cloud_authentication_choice,
      'fa fa-lock fa-lg',
      t = N_('Authentication'),
      t,
      :items => [
        button(
          :ems_cloud_recheck_auth_status,
          'fa fa-search fa-lg',
          N_('Re-check Authentication Status for this Cloud Provider'),
          N_('Re-check Authentication Status'),
          :klass => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :authentication_status}),
      ]
    ),
  ])
end
