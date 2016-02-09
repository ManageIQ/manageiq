class ApplicationHelper::Toolbar::MiqAeMethodCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_method_vmdb', [
    {
      :buttonSelect => "miq_ae_method_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_method_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Method"),
          :title        => N_("Edit this Method"),
        },
        {
          :button       => "miq_ae_method_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Method"),
          :title        => N_("Copy this Method"),
        },
        {
          :button       => "miq_ae_method_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Method"),
          :title        => N_("Remove this Method"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to remove this Method?"),
        },
      ]
    },
  ])
end
