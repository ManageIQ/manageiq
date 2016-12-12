class ApplicationHelper::Toolbar::OpenstackVmCloudCenter < ApplicationHelper::Toolbar::Basic
  button_group('instance_vmdb', [
    select(
      :instance_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :instance_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this Instance'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Instance?")),
        button(
          :instance_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this Instance'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this Instance?"),
          :klass   => ApplicationHelper::Button::VmInstanceTemplateScan),
        separator,
        button(
          :instance_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Instance'),
          t),
        button(
          :instance_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for this Instance'),
          N_('Set Ownership')),
        button(
          :instance_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Instance'),
          N_('Remove Instance'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Instance and ALL of its components will be permanently removed!")),
        button(
          :instance_evm_relationship,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Management Engine Relationship'),
          t),
        separator,
        button(
          :instance_attach,
          'pficon pficon-volume fa-lg',
          t = N_('Attach a Cloud Volume to this Instance'),
          t),
        button(
          :instance_detach,
          'pficon pficon-volume fa-lg',
          t = N_('Detach a Cloud Volume from this Instance'),
          t,
          :klass => ApplicationHelper::Button::InstanceDetach),
        button(
          :instance_associate_floating_ip,
          'fa fa-map-marker fa-lg',
          t = N_('Associate a Floating IP with this Instance'),
          t,
          :klass => ApplicationHelper::Button::InstanceAssociateFloatingIp),
        button(
          :instance_disassociate_floating_ip,
          'fa fa-map-marker fa-lg',
          t = N_('Disassociate a Floating IP from this Instance'),
          t,
          :klass => ApplicationHelper::Button::InstanceDisassociateFloatingIp),
        button(
          :instance_resize,
          'pficon pficon-edit fa-lg',
          t = N_('Reconfigure this Instance'),
          t,
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :resize}),
        button(
          :vm_right_size,
          'product product-custom-6 fa-lg',
          N_('CPU/Memory Recommendations of this VM'),
          N_('Right-Size Recommendations')),
      ]
    ),
  ])
  button_group('instance_policy', [
    select(
      :instance_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :instance_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Instance'),
          N_('Manage Policies')),
        button(
          :instance_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for this Instance'),
          N_('Policy Simulation')),
        button(
          :instance_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Instance'),
          N_('Edit Tags')),
        button(
          :instance_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Instance'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this Instance?")),
      ]
    ),
  ])
  button_group('instance_lifecycle', [
    select(
      :instance_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :instance_retire,
          'fa fa-clock-o fa-lg',
          N_('Set Retirement Dates for this Instance'),
          N_('Set Retirement Date')),
        button(
          :instance_retire_now,
          'fa fa-clock-o fa-lg',
          t = N_('Retire this Instance'),
          t,
          :confirm => N_("Retire this Instance?")),
        button(
          :instance_live_migrate,
          'product product-migrate fa-lg',
          t = N_('Migrate Instance'),
          t,
          :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options   => {:feature => :live_migrate},
          :url_parms => 'main_div'),
        button(
          :instance_evacuate,
          'product product-migrate fa-lg',
          t = N_('Evacuate Instance'),
          t,
          :klass     => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options   => {:feature => :evacuate},
          :url_parms => 'main_div')
      ]
    ),
  ])
  button_group('instance_monitoring', [
    select(
      :instance_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :instance_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Instance'),
          N_('Utilization'),
          :url_parms => "?display=performance"),
        button(
          :instance_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Instance'),
          N_('Timelines'),
          :klass     => ApplicationHelper::Button::GenericFeatureButton,
          :options   => {:feature => :timeline},
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  include ApplicationHelper::Toolbar::Cloud::InstanceOperationsButtonGroupMixin
end
