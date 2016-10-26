class ApplicationHelper::Toolbar::MiqAeNamespaceCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_namespace_vmdb', [
    select(
      :miq_ae_namespace_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_namespace_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Namespace'),
          t,
          :klass => ApplicationHelper::Button::MiqAeNamespaceEdit),
        button(
          :miq_ae_namespace_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Namespace'),
          t,
          :confirm => N_("Are you sure you want to remove this Namespace?"),
          :klass   => ApplicationHelper::Button::MiqAeDefault),
        separator,
        button(
          :miq_ae_namespace_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Namespace'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_class_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Class'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_item_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit Selected Item'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_class_copy,
          'fa fa-files-o fa-lg',
          N_('Select Classes to copy'),
          N_('Copy selected Classes'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeClassCopy),
        button(
          :miq_ae_class_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected Items'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove selected Items?"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
