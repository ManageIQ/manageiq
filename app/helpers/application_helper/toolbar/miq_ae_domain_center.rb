class ApplicationHelper::Toolbar::MiqAeDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_domain_vmdb', [
    {
      :buttonSelect => "miq_ae_domain_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_domain_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Domain"),
          :title        => N_("Edit this Domain"),
        },
        {
          :button       => "miq_ae_domain_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Domain"),
          :title        => N_("Remove this Domain"),
          :confirm      => N_("Are you sure you want to remove this Domain?"),
        },
        {
          :button       => "miq_ae_domain_unlock",
          :icon         => "fa fa-check fa-lg",
          :text         => N_("Unlock this Domain"),
          :title        => N_("Unlock this Domain"),
        },
        {
          :button       => "miq_ae_domain_lock",
          :icon         => "fa fa-ban fa-lg",
          :text         => N_("Lock this Domain"),
          :title        => N_("Lock this Domain"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_ae_namespace_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Namespace"),
          :title        => N_("Add a New Namespace"),
        },
        {
          :button       => "miq_ae_namespace_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Namespace"),
          :title        => N_("Select a single Namespace to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_ae_namespace_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Namespaces"),
          :title        => N_("Remove selected Namespaces"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove the selected Namespaces?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
