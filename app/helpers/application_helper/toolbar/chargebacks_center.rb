class ApplicationHelper::Toolbar::ChargebacksCenter < ApplicationHelper::Toolbar::Basic
  button_group('chargeback_vmdb', [
    select(
      :chargeback_vmdb_choice,
      'fa fa-cog fa-lg',
      t = N_('Configuration'),
      t,
      :items => [
        button(
          :chargeback_rates_new,
          'pficon pficon-add-circle-o fa-lg',
          t = N_('Add a new Chargeback Rate'),
          t,
          :klass => ApplicationHelper::Button::ChargebackRates),
        button(
          :chargeback_rates_edit,
          'pficon pficon-edit fa-lg',
          t = N_('Edit the selected Chargeback Rate'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass => ApplicationHelper::Button::ChargebackRates),
        button(
          :chargeback_rates_copy,
          'fa fa-files-o fa-lg',
          t = N_('Copy the selected Chargeback Rate to a new Chargeback Rate'),
          t,
          :url_parms => "main_div",
          :enabled   => false,
          :onwhen    => "1",
          :klass => ApplicationHelper::Button::ChargebackRates),
        button(
          :chargeback_rates_delete,
          'pficon pficon-delete fa-lg',
          t = N_('Remove selected Chargeback Rates from the VMDB'),
          t,
          :url_parms => "main_div",
          :confirm   => N_("Warning: The selected Chargeback Rate will be permanently removed!"),
          :enabled   => false,
          :onwhen    => "1+",
          :klass => ApplicationHelper::Button::ChargebackRates)
      ]
    ),
  ])
end
