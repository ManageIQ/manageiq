class ApplicationHelper::Toolbar::MiqAeMethodsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_method_vmdb', [
    select(
      :miq_ae_method_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_class_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Class'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_class_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Class'),
          t,
          :klass => ApplicationHelper::Button::MiqAeClassCopy),
        button(
          :miq_ae_class_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Class'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to remove this Class?"),
          :klass => ApplicationHelper::Button::MiqAeDefault),
        separator,
        button(
          :miq_ae_method_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Method'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_method_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Method to edit'),
          N_('Edit Selected Method'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_method_copy,
          'fa fa-files-o fa-lg',
          N_('Select Methods to copy'),
          N_('Copy selected Methods'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeInstanceCopy),
        button(
          :miq_ae_method_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Methods'),
          N_('Remove Methods'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove the selected Methods?"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
