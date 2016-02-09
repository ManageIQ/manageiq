class ApplicationHelper::Toolbar::MiqAeInstancesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_instance_vmdb', [
    {
      :buttonSelect => "miq_ae_instance_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_class_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Class"),
          :title        => N_("Edit this Class"),
        },
        {
          :button       => "miq_ae_class_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Class"),
          :title        => N_("Copy this Class"),
        },
        {
          :button       => "miq_ae_class_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Class"),
          :title        => N_("Remove this Class"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to remove this Class?"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "miq_ae_instance_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Instance"),
          :title        => N_("Add a New Instance"),
        },
        {
          :button       => "miq_ae_instance_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Instance"),
          :title        => N_("Select a single Instance to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_ae_instance_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy selected Instances"),
          :title        => N_("Select Instances to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_ae_instance_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Instances"),
          :title        => N_("Remove selected Instances"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove the selected Instances?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
