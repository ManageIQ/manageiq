class ApplicationHelper::Toolbar::MiqAeDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_domain_vmdb', [
    select(:miq_ae_domain_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:miq_ae_domain_edit, 'pficon pficon-edit fa-lg', N_('Edit this Domain'), N_('Edit this Domain')),
        button(:miq_ae_domain_delete, 'pficon pficon-delete fa-lg', N_('Remove this Domain'), N_('Remove this Domain'),
          :confirm   => N_("Are you sure you want to remove this Domain?")),
        button(:miq_ae_domain_unlock, 'fa fa-check fa-lg', N_('Unlock this Domain'), N_('Unlock this Domain')),
        button(:miq_ae_domain_lock, 'fa fa-ban fa-lg', N_('Lock this Domain'), N_('Lock this Domain')),
        separator,
        button(:miq_ae_namespace_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a New Namespace'), N_('Add a New Namespace')),
        button(:miq_ae_namespace_edit, 'pficon pficon-edit fa-lg', N_('Select a single Namespace to edit'), N_('Edit Selected Namespace'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:miq_ae_namespace_delete, 'pficon pficon-delete fa-lg', N_('Remove selected Namespaces'), N_('Remove Namespaces'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove the selected Namespaces?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
