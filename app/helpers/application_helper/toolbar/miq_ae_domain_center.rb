class ApplicationHelper::Toolbar::MiqAeDomainCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_domain_vmdb', [
    select(
      :miq_ae_domain_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_domain_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Domain'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDomainEdit),
        button(
          :miq_ae_domain_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Domain'),
          t,
          :confirm => N_("Are you sure you want to remove this Domain?"),
          :klass   => ApplicationHelper::Button::MiqAeDomainDelete),
        button(
          :miq_ae_domain_unlock,
          'fa fa-check fa-lg',
          t = N_('Unlock this Domain'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDomainUnlock),
        button(
          :miq_ae_domain_lock,
          'fa fa-ban fa-lg',
          t = N_('Lock this Domain'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDomainLock),
        button(
          :miq_ae_git_refresh,
          'fa fa-lg fa-refresh',
          t = N_('Refresh with a new branch or tag'),
          t,
          :klass => ApplicationHelper::Button::MiqAeGitRefresh),
        separator,
        button(
          :miq_ae_namespace_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Namespace'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_namespace_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Namespace to edit'),
          N_('Edit Selected Namespace'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::MiqAeNamespaceEdit),
        button(
          :miq_ae_namespace_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Namespaces'),
          N_('Remove Namespaces'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove the selected Namespaces?"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
