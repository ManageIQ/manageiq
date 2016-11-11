class ApplicationHelper::Toolbar::MiqAeInstancesCenter < ApplicationHelper::Toolbar::Basic
  button_group('miq_ae_instance_vmdb', [
    select(
      :miq_ae_instance_vmdb_choice,
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
          :miq_ae_instance_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a New Instance'),
          t,
          :klass => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_instance_edit,
          'pficon pficon-edit fa-lg',
          N_('Select a single Instance to edit'),
          N_('Edit Selected Instance'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
        button(
          :miq_ae_instance_copy,
          'fa fa-files-o fa-lg',
          N_('Select Instances to copy'),
          N_('Copy selected Instances'),
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeInstanceCopy),
        button(
          :miq_ae_instance_delete,
          'pficon pficon-delete fa-lg',
          N_('Remove selected Instances'),
          N_('Remove Instances'),
          :url_parms => "main_div",
          :confirm   => N_("Are you sure you want to remove the selected Instances?"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass     => ApplicationHelper::Button::MiqAeDefault),
      ]
    ),
  ])
end
