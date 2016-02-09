class ApplicationHelper::Toolbar::MiqWidgetSetsCenter < ApplicationHelper::Toolbar::Basic
  button_group('db_vmdb', [
    {
      :buttonSelect => "db_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "db_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Dashboard"),
          :title        => N_("Add a new Dashboard"),
        },
        {
          :separator    => nil,
        },
        {
          :button       => "db_seq_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit Sequence of Dashboards"),
          :title        => N_("Edit Sequence of Dashboards"),
        },
      ]
    },
  ])
end
