class ApplicationHelper::Toolbar::XEditView < ApplicationHelper::Toolbar::Basic
  button_group('form_buttons', [
    {
      :button       => "button_add",
      :icon         => "pficon pficon-add-circle-o fa-lg",
      :title        => N_("Add"),
      :text         => N_("Add"),
      :url          => "\#{@edit[:url]}",
      :url_parms    => "?button=add",
    },
    {
      :button       => "button_save",
      :icon         => "fa fa-floppy-o fa-lg",
      :title        => N_("Save Changes"),
      :text         => N_("Save"),
      :url          => "\#{@edit[:url]}",
      :url_parms    => "?button=save",
    },
    {
      :button       => "button_reset",
      :icon         => "fa fa-reply fa-lg",
      :title        => N_("Reset"),
      :text         => N_("Reset"),
      :url          => "\#{@edit[:url]}",
      :url_parms    => "?button=reset",
    },
    {
      :button       => "button_cancel",
      :icon         => "fa fa-ban fa-lg",
      :title        => N_("Cancel Changes"),
      :text         => N_("Cancel"),
      :url          => "\#{@edit[:url]}",
      :url_parms    => "?button=cancel",
    },
  ])
end
