class ApplicationHelper::Toolbar::MiqAeNamespaceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_namespace_vmdb', [
    select(:miq_ae_namespace_vmdb_choice, 'fa fa-cog fa-lg', N_('Configuration'), N_('Configuration'),
      :items     => [
        button(:miq_ae_namespace_edit, 'pficon pficon-edit fa-lg', N_('Edit this Namespace'), N_('Edit this Namespace')),
        button(:miq_ae_namespace_delete, 'pficon pficon-delete fa-lg', N_('Remove this Namespace'), N_('Remove this Namespace'),
          :confirm   => N_("Are you sure you want to remove this Namespace?")),
        separator,
        button(:miq_ae_namespace_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a New Namespace'), N_('Add a New Namespace')),
        button(:miq_ae_class_new, 'pficon pficon-add-circle-o fa-lg', N_('Add a New Class'), N_('Add a New Class')),
        button(:miq_ae_item_edit, 'pficon pficon-edit fa-lg', N_('Edit Selected Item'), N_('Edit Selected Item'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1"),
        button(:miq_ae_class_copy, 'fa fa-files-o fa-lg', N_('Select Classes to copy'), N_('Copy selected Classes'),
          :url_parms => "main_div",
          :enabled   => "false",
          :onwhen    => "1+"),
        button(:miq_ae_namespace_delete, 'pficon pficon-delete fa-lg', N_('Remove selected Items'), N_('Remove selected Items'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove selected Items?"),
          :enabled   => "false",
          :onwhen    => "1+"),
      ]
    ),
  ])
end
