class ApplicationHelper::Toolbar::MiqAeFieldsCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_field_vmdb', [
    select(
      :miq_ae_field_vmdb_choice,
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
          :klass     => ApplicationHelper::Button::MiqAeDefault),
        separator,
        button(
          :miq_ae_field_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit selected Schema'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_field_seq,
          'pficon pficon-edit fa-lg',
          N_('Edit sequence of Class Schema'),
          N_('Edit sequence'),
          :klass => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
