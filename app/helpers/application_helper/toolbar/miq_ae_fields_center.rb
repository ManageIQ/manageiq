class ApplicationHelper::Toolbar::MiqAeFieldsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_field_vmdb', [
    {
      :buttonSelect => "miq_ae_field_vmdb_choice",
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
          :button       => "miq_ae_field_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit selected Schema"),
          :title        => N_("Edit selected Schema"),
        },
        {
          :button       => "miq_ae_field_seq",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit sequence"),
          :title        => N_("Edit sequence of Class Schema"),
        },
      ]
    },
  ])
end
