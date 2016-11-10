class ApplicationHelper::Toolbar::DriftCenter < ApplicationHelper::Toolbar::Basic
  button_group('drift_tasks', [
    twostate(
      :drift_all,
      'product product-compare_all fa-lg',
      N_('All attributes'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "drift_all",
      :url_parms => "?id=\#{$vms_comp}&compare_task=all&db=\#{@compare_db}&id=\#{@drift_obj.id}"),
    twostate(
      :drift_diff,
      'product product-compare_diff fa-lg',
      N_('Attributes with different values'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "drift_differences",
      :url_parms => "?id=\#{$vms_comp}&compare_task=different&db=\#{@compare_db}&id=\#{@drift_obj.id}"),
    twostate(
      :drift_same,
      'product product-compare_same fa-lg',
      N_('Attributes with same values'),
      nil,
      :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url       => "drift_same",
      :url_parms => "?id=\#{$vms_comp}&compare_task=same&db=\#{@compare_db}&id=\#{@drift_obj.id}"),
  ])
  button_group('compare_mode', [
    twostate(
      :driftmode_details,
      'fa fa-bars fa-lg',
      N_('Details Mode'),
      nil,
      :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "drift_mode"),
    twostate(
      :driftmode_exists,
      'product product-exists fa-lg',
      N_('Exists Mode'),
      nil,
      :klass => ApplicationHelper::Button::ButtonWithoutRbacCheck,
      :url => "drift_mode"),
  ])
end
