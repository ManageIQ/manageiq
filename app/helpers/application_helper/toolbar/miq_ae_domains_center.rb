class ApplicationHelper::Toolbar::MiqAeDomainsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_domain_vmdb', [
    {
      :buttonSelect => "miq_ae_domain_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_domain_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Domain"),
          :title        => N_("Add a New Domain"),
        },
        {
          :button       => "miq_ae_domain_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Domains"),
          :title        => N_("Select a single Domains to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_ae_domain_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Domains"),
          :title        => N_("Remove selected Domains"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove the selected Domains?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_ae_domain_priority_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Priority Order of Domains"),
          :title        => N_("Edit Priority Order  of Domains"),
        },
      ]
    },
  ])
end
