class ApplicationHelper::Toolbar::XMiqTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_template_vmdb', [
    select(
      :miq_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_template_refresh,
          'fa fa-refresh fa-lg',
          N_('Refresh relationships and power states for all items related to this Template'),
          N_('Refresh Relationships and Power States'),
          :confirm => N_("Refresh relationships and power states for all items related to this Template?"),
          :klass => ApplicationHelper::Button::TemplateRefresh),
        button(
          :miq_template_scan,
          'fa fa-search fa-lg',
          N_('Perform SmartState Analysis on this Template'),
          N_('Perform SmartState Analysis'),
          :confirm => N_("Perform SmartState Analysis on this Template?"),
          :klass => ApplicationHelper::Button::VmInstanceTemplateScan),
        separator,
        button(
          :miq_template_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Template'),
          t),
        button(
          :miq_template_ownership,
          'pficon pficon-user fa-lg',
          N_('Set Ownership for this Template'),
          N_('Set Ownership')),
        button(
          :miq_template_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove this Template'),
          N_('Remove Template'),
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Template and ALL of its components will be permanently removed!")),
      ]
    ),
  ])
  button_group('miq_template_policy', [
    select(
      :miq_template_policy_choice,
      'fa fa-shield fa-lg',
      t = N_('Policy'),
      t,
      :items => [
        button(
          :miq_template_protect,
          'pficon pficon-edit fa-lg',
          N_('Manage Policies for this Template'),
          N_('Manage Policies'),
          :klass => ApplicationHelper::Button::VmTemplatePolicy),
        button(
          :miq_template_policy_sim,
          'fa fa-play-circle-o fa-lg',
          N_('View Policy Simulation for this Template'),
          N_('Policy Simulation'),
          :klass => ApplicationHelper::Button::VmTemplatePolicy),
        button(
          :miq_template_tag,
          'pficon pficon-edit fa-lg',
          N_('Edit Tags for this Template'),
          N_('Edit Tags')),
        button(
          :miq_template_check_compliance,
          'fa fa-search fa-lg',
          N_('Check Compliance of the last known configuration for this Template'),
          N_('Check Compliance of Last Known Configuration'),
          :confirm => N_("Initiate Check Compliance of the last known configuration for this Template?")),
      ]
    ),
  ])
  button_group('miq_template_lifecycle', [
    select(
      :miq_template_lifecycle_choice,
      'fa fa-recycle fa-lg',
      t = N_('Lifecycle'),
      t,
      :items => [
        button(
          :miq_template_miq_request_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Provision VMs using this Template'),
          t,
          :klass   => ApplicationHelper::Button::GenericFeatureButtonWithDisable,
          :options => {:feature => :provisioning}),
        button(
          :miq_template_clone,
          'product product-clone fa-lg',
          t = N_('Clone this Template'),
          t,
          :klass => ApplicationHelper::Button::GenericFeatureButton,
          :options => {:feature => :clone}),
      ]
    ),
  ])
  button_group('miq_template_monitoring', [
    select(
      :miq_template_monitoring_choice,
      'product product-monitoring fa-lg',
      t = N_('Monitoring'),
      t,
      :items => [
        button(
          :miq_template_perf,
          'product product-monitoring fa-lg',
          N_('Show Capacity & Utilization data for this Template'),
          N_('Utilization'),
          :url_parms => "?display=performance"),
        button(
          :miq_template_timeline,
          'product product-timeline fa-lg',
          N_('Show Timelines for this Template'),
          N_('Timelines'),
          :url_parms => "?display=timeline"),
      ]
    ),
  ])
  button_group('snapshot_tasks', [
    button(
      :miq_template_snapshot_add,
      'pficon pficon-add-circle-o fa-lg',
      N_('Create a new snapshot for this Template'),
      nil,
      :onwhen => "1"),
    select(
      :miq_template_delete_snap_choice,
      'pficon pficon-delete fa-lg',
      N_('Delete Snapshots'),
      nil,
      :items => [
        button(
          :miq_template_snapshot_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Delete Selected Snapshot'),
          t,
          :confirm   => N_("The selected snapshot will be permanently deleted. Are you sure you want to delete the selected snapshot?"),
          :url_parms => "main_div",
          :onwhen    => "1"),
        button(
          :miq_template_snapshot_delete_all,
          'pficon pficon-delete fa-lg',
          t = N_('Delete All Existing Snapshots'),
          t,
          :confirm => N_("Delete all of this Templates existing snapshots?")),
      ]
    ),
    button(
      :miq_template_snapshot_revert,
      'fa fa-undo fa-lg',
      N_('Revert to selected snapshot'),
      nil,
      :confirm => N_("This Template will revert to selected snapshot. Are you sure you want to revert to the selected snapshot?"),
      :onwhen  => "1"),
  ])
  button_group('vmtree_tasks', [
    button(
      :miq_template_tag,
      'pficon pficon-edit fa-lg',
      N_('Edit Tags for this Template'),
      nil),
    button(
      :miq_template_compare,
      'product product-compare fa-lg',
      N_('Compare selected Templates'),
      nil,
      :url_parms => "main_div",
      :enabled   => false,
      :onwhen    => "2+"),
  ])
end
