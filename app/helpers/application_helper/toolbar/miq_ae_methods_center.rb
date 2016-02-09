class ApplicationHelper::Toolbar::MiqAeMethodsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_method_vmdb', [
    {
      :buttonSelect => "miq_ae_method_vmdb_choice",
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
          :button       => "miq_ae_method_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Method"),
          :title        => N_("Add a New Method"),
        },
        {
          :button       => "miq_ae_method_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Method"),
          :title        => N_("Select a single Method to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_ae_method_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy selected Methods"),
          :title        => N_("Select Methods to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_ae_method_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove Methods"),
          :title        => N_("Remove selected Methods"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove the selected Methods?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
