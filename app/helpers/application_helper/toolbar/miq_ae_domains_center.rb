class ApplicationHelper::Toolbar::MiqAeDomainsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_domain_vmdb', [
    select(
      :miq_ae_domain_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_domain_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Domain'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefaultNoRecord),
        button(
          :miq_ae_domain_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Domains to edit'),
          N_('Edit Selected Domains'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::MiqAeDefaultNoRecord),
        button(
          :miq_ae_domain_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Domains'),
          N_('Remove Domains'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove the selected Domains?"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeDefaultNoRecord),
        separator,
        button(
          :miq_ae_domain_priority_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Priority Order of Domains'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDomainPriorityEdit),
      ]
    ),
  ])
end
