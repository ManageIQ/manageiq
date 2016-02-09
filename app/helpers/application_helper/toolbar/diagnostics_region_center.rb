class ApplicationHelper::Toolbar::DiagnosticsRegionCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    {
      :button       => "reload_server_tree",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload Current Display"),
    },
  ])
  button_group('ldap_domain_vmdb', [
    {
      :buttonSelect => "support_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "delete_server",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete Server \#{@record.name} [\#{@record.id}]"),
          :title        => N_("Delete Server \#{@record.name} [\#{@record.id}]"),
          :confirm      => N_("Do you want to delete Server \#{@record.name} [\#{@record.id}]?"),
        },
        {
          :button       => "role_start",
          :icon         => "fa fa-play-circle-o fa-lg",
          :text         => N_("Start Role"),
          :title        => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]"),
          :confirm      => N_("Start the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?"),
        },
        {
          :button       => "role_suspend",
          :icon         => "fa fa-pause-circle-o fa-lg",
          :text         => N_("Suspend Role"),
          :title        => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]"),
          :confirm      => N_("Suspend the \#{@record.server_role.description} Role on Server \#{@record.miq_server.name} [\#{@record.miq_server.id}]?"),
        },
        {
          :button       => "demote_server",
          :icon         => "pficon pficon-delete fa-lg_master",
          :text         => N_("Demote Server"),
          :title        => N_("Demote Server \#{@record.miq_server.name} [\#{@record.miq_server.id}] to secondary for the \#{@record.server_role.description} Role"),
          :confirm      => N_("Do you want to demote this Server to secondary?  This will leave no primary Server for this Role."),
        },
        {
          :button       => "promote_server",
          :icon         => "product product-migrate fa-lg",
          :text         => N_("Promote Server"),
          :title        => N_("Promote Server \#{@record.miq_server.name} [\#{@record.miq_server.id}] to primary for the \#{@record.server_role.description} Role"),
          :confirm      => N_("Do you want to promote this Server to primary?  This will replace any existing primary Server for this Role."),
        },
      ]
    },
  ])
end
