class ApplicationHelper::Toolbar::MiqPolicyRsopCenter < ApplicationHelper::Toolbar::Basic
  button_group('policy_rsop_vmdb', [
    button(
      :toggle_collapse,
      'fa-caret-square-o-up fa-lg',
      N_('Collapse All'),
      nil,
      :url => "rsop_toggle"),
    button(
      :toggle_expand,
      'fa-caret-square-o-down fa-lg',
      N_('Expand All'),
      nil,
      :url => "rsop_toggle"),
  ])
end
