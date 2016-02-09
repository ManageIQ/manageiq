class ApplicationHelper::Toolbar::MiqAeInstanceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_instance_vmdb', [
    {
      :buttonSelect => "miq_ae_instance_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "miq_ae_instance_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Instance"),
          :title        => N_("Edit this Instance"),
        },
        {
          :button       => "miq_ae_instance_copy",
          :icon         => "fa fa-files-o fa-lg",
          :text         => N_("Copy this Instance"),
          :title        => N_("Copy this Instance"),
        },
        {
          :button       => "miq_ae_instance_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove this Instance"),
          :title        => N_("Remove this Instance"),
          :url_parms    => "&refresh=y",
          :confirm      => N_("Are you sure you want to remove this Instance?"),
        },
      ]
    },
  ])
end
