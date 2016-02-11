class ApplicationHelper::Toolbar::BlankView < ApplicationHelper::Toolbar::Basic
  button_group('blank_buttons', [
    button(
      :blank_button,
      nil,
      nil,
      nil,
      :enabled => "false"),
  ])
end
