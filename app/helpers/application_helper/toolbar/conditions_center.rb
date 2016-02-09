class ApplicationHelper::Toolbar::ConditionsCenter < ApplicationHelper::Toolbar::Basic
  button_group('condition_vmdb', [
    {
      :buttonSelect => "condition_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "condition_new",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a New \#{@sb[:folder].upcase == \"VM\" ? \"VM\" : ui_lookup(:model=>@sb[:folder])} Condition"),
          :title        => N_("Add a New \#{@sb[:folder].upcase == \"VM\" ? \"VM\" : ui_lookup(:model=>@sb[:folder])} Condition"),
        },
      ]
    },
  ])
end
