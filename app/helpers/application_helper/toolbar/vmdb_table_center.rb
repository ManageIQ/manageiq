class ApplicationHelper::Toolbar::VmdbTableCenter < ApplicationHelper::Toolbar::Basic
  button_group('support_reloading', [
    button(
      :db_refresh,
      'fa fa-repeat fa-lg',
      N_('Reload Current Display'),
      nil),
  ])
end
