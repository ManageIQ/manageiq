class ApplicationHelper::Toolbar::MiqTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_template_vmdb', [
    {
      :buttonSelect => "miq_template_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_template_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this Template"),
          :confirm      => N_("Refresh relationships and power states for all items related to this Template?"),
        },
        {
          :button       => "miq_template_scan",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Perform SmartState Analysis"),
          :title        => N_("Perform SmartState Analysis on this Template"),
          :confirm      => N_("Perform SmartState Analysis on this Template?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_template_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Template"),
          :title        => N_("Edit this Template"),
          :url          => "/edit",
        },
        {
          :button       => "miq_template_ownership",
          :icon         => "pficon pficon-user fa-lg",
          :text         => N_("Set Ownership"),
          :title        => N_("Set Ownership for this Template"),
        },
        {
          :button       => "miq_template_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Template from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Template and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Template?"),
        },
      ]
    },
  ])
  button_group('miq_template_policy', [
    {
      :buttonSelect => "miq_template_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "miq_template_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this Template"),
        },
        {
          :button       => "miq_template_policy_sim",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Policy Simulation"),
          :title        => N_("View Policy Simulation for this Template"),
        },
        {
          :button       => "miq_template_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Template"),
        },
        {
          :button       => "miq_template_check_compliance",
          :icon         => "fa fa-search fa-lg",
          :text         => N_("Check Compliance of Last Known Configuration"),
          :title        => N_("Check Compliance of the last known configuration for this Template"),
          :confirm      => N_("Initiate Check Compliance of the last known configuration for this Template?"),
        },
      ]
    },
  ])
  button_group('miq_template_lifecycle', [
    {
      :buttonSelect => "miq_template_lifecycle_choice",
      :icon         => "fa fa-recycle fa-lg",
      :title        => N_("Lifecycle"),
      :text         => N_("Lifecycle"),
      :items => [
        {
          :button       => "miq_template_clone",
          :icon         => "product product-clone fa-lg",
          :text         => N_("Clone this Template"),
          :title        => N_("Clone this Template"),
        },
      ]
    },
  ])
  button_group('miq_template_monitoring', [
    {
      :buttonSelect => "miq_template_monitoring_choice",
      :icon         => "product product-monitoring fa-lg",
      :title        => N_("Monitoring"),
      :text         => N_("Monitoring"),
      :items => [
        {
          :button       => "miq_template_perf",
          :icon         => "product product-monitoring fa-lg",
          :text         => N_("Utilization"),
          :title        => N_("Show Capacity & Utilization data for this Template"),
          :url          => "/show",
          :url_parms    => "?display=performance",
        },
        {
          :button       => "miq_template_timeline",
          :icon         => "product product-timeline fa-lg",
          :text         => N_("Timelines"),
          :title        => N_("Show Timelines for this Template"),
          :url          => "/show",
          :url_parms    => "?display=timeline",
        },
      ]
    },
  ])
  button_group('snapshot_tasks', [
    {
      :button       => "miq_template_snapshot_add",
      :icon         => "pficon pficon-add-circle-o fa-lg",
      :title        => N_("Create a new snapshot for this Template"),
      :url          => "/snap",
      :onwhen       => "1",
    },
    {
      :buttonSelect => "miq_template_delete_snap_choice",
      :icon         => "pficon pficon-delete fa-lg",
      :title        => N_("Delete Snapshots"),
      :items => [
        {
          :button       => "miq_template_snapshot_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete Selected Snapshot"),
          :title        => N_("Delete Selected Snapshot"),
          :confirm      => N_("The selected snapshot will be permanently deleted. Are you sure you want to delete the selected snapshot?"),
          :url_parms    => "main_div",
          :onwhen       => "1",
        },
        {
          :button       => "miq_template_snapshot_delete_all",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete All Existing Snapshots"),
          :title        => N_("Delete All Existing Snapshots"),
          :confirm      => N_("Delete all of this Templates existing snapshots?"),
        },
      ]
    },
    {
      :button       => "miq_template_snapshot_revert",
      :icon         => "fa fa-undo fa-lg",
      :title        => N_("Revert to selected snapshot"),
      :confirm      => N_("This Template will revert to selected snapshot. Are you sure you want to revert to the selected snapshot?"),
      :onwhen       => "1",
    },
  ])
  button_group('vmtree_tasks', [
    {
      :button       => "miq_template_tag",
      :icon         => "pficon pficon-edit fa-lg",
      :title        => N_("Edit Tags for this Template"),
    },
    {
      :button       => "miq_template_compare",
      :icon         => "product product-compare fa-lg",
      :title        => N_("Compare selected Templates"),
      :url_parms    => "main_div",
      :enabled      => "false",
      :onwhen       => "2+",
    },
  ])
end
