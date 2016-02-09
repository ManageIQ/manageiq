class ApplicationHelper::Toolbar::TimeProfilesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_schedule_vmdb', [
    {
      :buttonSelect => "miq_schedule_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "timeprofile_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Time Profile"),
          :title        => N_("Add a new Time Profile"),
          :url          => "/timeprofile_new",
        },
        {
          :button       => "tp_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit selected Time Profile"),
          :title        => N_("Select a single Time Profile to edit"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "tp_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Select a single Time Profile to copy"),
          :text         => N_("Copy selected Time Profile"),
          :url_parms    => "main_div",
          :enabled      => "false",
          :onwhen       => "1",
        },
        {
          :button       => "tp_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Delete selected Time Profiles"),
          :title        => N_("Delete selected Time Profiles"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: The selected Time Profiles will be permanently removed from the VMDB. Are you sure you want to delete the selected Time Profiles?"),
          :enabled      => "false",
          :onwhen       => "1+",
        },
      ]
    },
  ])
end
