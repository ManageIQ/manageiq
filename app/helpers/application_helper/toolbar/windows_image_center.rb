class ApplicationHelper::Toolbar::WindowsImageCenter < ApplicationHelper::Toolbar::Basic
  button_group('pxe_wimg_vmdb', [
    {
      :buttonSelect => "pxe_wimg_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "pxe_wimg_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Windows Image"),
          :title        => N_("Edit this Windows Image"),
        },
      ]
    },
  ])
end
