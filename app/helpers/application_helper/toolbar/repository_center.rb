class ApplicationHelper::Toolbar::RepositoryCenter < ApplicationHelper::Toolbar::Basic
  button_group('repository_vmdb', [
    {
      :buttonSelect => "repository_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "repository_refresh",
          :icon         => "fa fa-refresh fa-lg",
          :text         => N_("Refresh Relationships and Power States"),
          :title        => N_("Refresh relationships and power states for all items related to this Repository"),
          :confirm      => N_("Refresh relationships and power states for all items related to this Repository?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "repository_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Repository"),
          :title        => N_("Edit this Repository"),
          :url          => "/edit",
        },
        {
          :button       => "repository_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Repository from the VMDB"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Warning: This Repository and ALL of its components will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Repository?"),
        },
      ]
    },
  ])
  button_group('repository_policy', [
    {
      :buttonSelect => "repository_policy_choice",
      :icon         => "fa fa-shield fa-lg",
      :title        => N_("Policy"),
      :text         => N_("Policy"),
      :items => [
        {
          :button       => "repository_protect",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Manage Policies"),
          :title        => N_("Manage Policies for this Repository"),
        },
        {
          :button       => "repository_tag",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Tags"),
          :title        => N_("Edit Tags for this Repository"),
        },
      ]
    },
  ])
end
