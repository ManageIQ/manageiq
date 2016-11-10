class ApplicationHelper::Toolbar::MiqAeMethodCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_method_vmdb', [
    select(
      :miq_ae_method_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :miq_ae_method_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Method'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_method_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Method'),
          t,
          :klass => ApplicationHelper::Button::MiqAeInstanceCopy),
        button(
          :miq_ae_method_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Method'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Are you sure you want to remove this Method?"),
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
