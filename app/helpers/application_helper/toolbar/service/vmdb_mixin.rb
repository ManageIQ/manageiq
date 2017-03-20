module ApplicationHelper::Toolbar::Service::VmdbMixin
  def self.included(included_class)
    included_class.button_group('service_vmdb', [
      included_class.select(
        :service_vmdb_choice,
        'fa fa-cog fa-lg',
        t = N_('Configuration'),
        t,
        :enabled => false,
        :onwhen  => "1+",
        :items   => [
          included_class.button(
            :service_edit,
            'pficon pficon-edit fa-lg',
            N_('Select a single service to edit'),
            N_('Edit Selected Service'),
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1"),
          included_class.button(
            :service_delete,
            'pficon pficon-delete fa-lg',
            N_('Remove selected Services'),
            N_('Remove Services'),
            :url_parms => "main_div",
            :enabled   => false,
            :confirm   => N_("Warning: The selected Services and ALL of their components will be permanently removed!"),
            :onwhen    => "1+"),
          included_class.separator,
          included_class.button(
            :service_ownership,
            'pficon pficon-user fa-lg',
            N_('Set Ownership for the selected Services'),
            N_('Set Ownership'),
            :url_parms => "main_div",
            :enabled   => false,
            :onwhen    => "1+"),
        ]
      ),
    ])
  end
end
