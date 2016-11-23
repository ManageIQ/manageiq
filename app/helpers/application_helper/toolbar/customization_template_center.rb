class ApplicationHelper::Toolbar::CustomizationTemplateCenter < ApplicationHelper::Toolbar::Basic
  button_group('customization_template_vmdb', [
    select(
      :customization_template_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :customization_template_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy this Customization Template'),
          t,
          :klass => ApplicationHelper::Button::CustomizationTemplateCopy),
        button(
          :customization_template_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit this Customization Template'),
          t,
          :klass => ApplicationHelper::Button::CustomizationTemplate),
        button(
          :customization_template_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove this Customization Template'),
          t,
          :url_parms => "&refresh=y",
          :confirm   => N_("Warning: This Customization Template will be permanently removed!"),
          :klass     => ApplicationHelper::Button::CustomizationTemplate),
      ]
    ),
  ])
end
