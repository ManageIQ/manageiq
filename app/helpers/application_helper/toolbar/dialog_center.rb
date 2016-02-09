class ApplicationHelper::Toolbar::DialogCenter < ApplicationHelper::Toolbar::Basic
  button_group('dialog_vmdb', [
    {
      :buttonSelect => "dialog_vmdb_choice",
      :icon         => "fa fa-cog fa-lg",
      :title        => N_("Configuration"),
      :text         => N_("Configuration"),
      :items => [
        {
          :button       => "dialog_edit",
          :icon         => "pficon pficon-edit fa-lg",
          :text         => N_("Edit this Dialog"),
          :title        => N_("Edit this Dialog"),
          :url_parms    => "main_div",
        },
        {
          :button       => "dialog_copy",
          :icon         => "fa fa-files-o fa-lg",
          :title        => N_("Copy this Dialog"),
          :text         => N_("Copy this Dialog"),
          :url_parms    => "main_div",
        },
        {
          :button       => "dialog_delete",
          :icon         => "pficon pficon-delete fa-lg",
          :text         => N_("Remove from the VMDB"),
          :title        => N_("Remove this Dialog from the VMDB"),
          :url_parms    => "main_div",
          :confirm      => N_("Warning: This Dialog will be permanently removed from the Virtual Management Database.  Are you sure you want to remove this Dialog?"),
        },
      ]
    },
  ])
  button_group('dialog_add', [
    {
      :buttonSelect => "dialog_add_choice",
      :icon         => "pficon pficon-add-circle-o fa-lg",
      :title        => N_("Add"),
      :enabled      => "true",
      :items => [
        {
          :button       => "dialog_add_tab",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Tab to this Dialog"),
          :title        => N_("Add a new Tab to this Dialog"),
          :url_parms    => "?typ=tab&id=\#{@edit[:rec_id]}",
        },
        {
          :button       => "dialog_add_box",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Box to this Tab"),
          :title        => N_("Add a new Box to this Tab"),
          :url_parms    => "?typ=box&id=\#{@edit[:rec_id]}",
        },
        {
          :button       => "dialog_add_element",
          :icon         => "pficon pficon-add-circle-o fa-lg",
          :text         => N_("Add a new Element to this Box"),
          :title        => N_("Add a new Element to this Box"),
          :url_parms    => "?typ=element&id=\#{@edit[:rec_id]}",
        },
      ]
    },
  ])
  button_group('dialog_discard', [
    {
      :button       => "dialog_res_discard",
      :icon         => "pficon pficon-close fa-lg",
      :title        => N_("Discard this new \#{@sb[:node_typ].titleize}"),
      :url_parms    => "?id=\#{@edit[:rec_id]}",
    },
  ])
  button_group('dialog_edit_delete', [
    {
      :button       => "dialog_resource_remove",
      :icon         => "pficon pficon-delete fa-lg",
      :title        => N_("Delete selected \#{@sb[:txt]}"),
      :url_parms    => "?id=\#{@edit[:rec_id]}",
    },
  ])
end
