class ApplicationHelper::Toolbar::MiqAeNamespaceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_namespace_vmdb', [
    {
      :buttonSelect => "miq_ae_namespace_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_namespace_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Namespace"),
          :title        => N_("Edit this Namespace"),
        },
        {
          :button       => "miq_ae_namespace_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Namespace"),
          :title        => N_("Remove this Namespace"),
          :confirm      => N_("Are you sure you want to remove this Namespace?"),
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
          :button       => "miq_ae_class_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New Class"),
          :title        => N_("Add a New Class"),
        },
        {
          :button       => "miq_ae_item_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Selected Item"),
          :title        => N_("Edit Selected Item"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "miq_ae_class_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy selected Classes"),
          :title        => N_("Select Classes to copy"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1+",
        },
        {
          :button       => "miq_ae_namespace_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove selected Items"),
          :title        => N_("Remove selected Items"),
          :url_parms    => "main_div",
          :confirm      => N_("Are you sure you want to remove selected Items?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
