class ApplicationHelper::Toolbar::MiqRequestCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_request_editing', [
    {
      :button       => "miq_request_copy",
      :icon         => "fa fa-files-o fa-lg",
      :title        => N_("Copy original Request"),
    },
    {
      :button       => "miq_request_edit",
      :icon         => "pficon pficon-edit fa-lg",
      :title        => N_("Edit the original Request"),
    },
    {
      :button       => "miq_request_delete",
      :icon         => "pficon pficon-delete fa-lg",
      :title        => N_("Delete this Request"),
      :url_parms    => "&refresh=y",
      :confirm      => N_("Are you sure you want to delete this Request?"),
    },
    {
      :button       => "miq_request_reload",
      :icon         => "fa fa-repeat fa-lg",
      :text         => N_("Reload"),
      :title        => N_("Reload the current display"),
      :url_parms    => "&display=miq_provisions",
    },
  ])
  button_group('miq_request_approve', [
    {
      :button       => "miq_request_approve",
      :icon         => "fa fa-check fa-lg",
      :title        => N_("Approve this Request"),
      :url          => "/stamp",
      :url_parms    => "?typ=a",
    },
    {
      :button       => "miq_request_deny",
      :icon         => "fa fa-ban fa-lg",
      :title        => N_("Deny this Request"),
      :url          => "/stamp",
      :url_parms    => "?typ=d",
    },
  ])
end
