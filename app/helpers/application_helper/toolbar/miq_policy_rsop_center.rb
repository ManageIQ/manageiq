class ApplicationHelper::Toolbar::MiqPolicyRsopCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_rsop_vmdb', [
    {
      :button       => "toggle_collapse",
      :icon         => "fa-caret-square-o-up fa-lg",
      :title        => N_("Collapse All"),
      :url          => "rsop_toggle",
    },
    {
      :button       => "toggle_expand",
      :icon         => "fa-caret-square-o-down fa-lg",
      :title        => N_("Expand All"),
      :url          => "rsop_toggle",
    },
  ])
end
