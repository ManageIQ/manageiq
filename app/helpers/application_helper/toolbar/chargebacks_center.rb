class ApplicationHelper::Toolbar::ChargebacksCenter < ApplicationHelper::Toolbar::Basic
  button_group('chargeback_vmdb', [
    {
      :buttonSelect => "chargeback_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "chargeback_rates_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Chargeback Rate"),
          :title        => N_("Add a new Chargeback Rate"),
        },
        {
          :button       => "chargeback_rates_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit the selected Chargeback Rate"),
          :title        => N_("Edit the selected Chargeback Rate"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "chargeback_rates_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Copy the selected Chargeback Rate to a new Chargeback Rate"),
          :text         => N_("Copy the selected Chargeback Rate to a new Chargeback Rate"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "chargeback_rates_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected Chargeback Rates from the VMDB"),
          :title        => N_("Remove selected Chargeback Rates from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Chargeback Rate will be permanently removed from the Virtual Management Database.  Are you sure you want to remove the selected Chargeback Rates?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
