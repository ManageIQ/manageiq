class ApplicationHelper::Toolbar::CompareCenter < ApplicationHelper::Toolbar::Basic
  button_group('comapre_tasks', [
    twostate(
      :compare_all,
      'product product-compare_all fa-lg',
      N_('All attributes'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "compare_miq_all",
      :url_parms => "?id=\#{$vms_comp}&compare_task=all"),
    twostate(
      :compare_diff,
      'product product-compare_diff fa-lg',
      N_('Attributes with different values'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "compare_miq_differences",
      :url_parms => "?id=\#{$vms_comp}&compare_task=different"),
    twostate(
      :compare_same,
      'product product-compare_same fa-lg',
      N_('Attributes with same values'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "compare_miq_same",
      :url_parms => "?id=\#{$vms_comp}&compare_task=same"),
  ])
  button_group('compare_mode', [
    twostate(
      :comparemode_details,
      'fa fa-bars fa-lg',
      N_('Details Mode'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "compare_mode"),
    twostate(
      :comparemode_exists,
      'product product-exists fa-lg',
      N_('Exists Mode'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "compare_mode"),
  ])
end
