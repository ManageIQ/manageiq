class ApplicationHelper::Toolbar::XHistory < ApplicationHelper::Toolbar::Basic
  button_group('history_main', [
    select(
      :history_choice,
      'fa fa-arrow-left fa-lg',
      N_('History'),
      nil,
      :klass => ApplicationHelper::Button::HistoryChoice,
      :items => (1..10).map do |level|
        button(
          "history_#{level}".to_sym,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :klass => ApplicationHelper::Button::HistoryItem,
          :url   => "x_history?item=#{level}"
        )
      end
    ),
    button(
      :summary_reload,
      'fa fa-repeat fa-lg',
      N_('Reload current display'),
      nil,
      :url => "reload",
      :klass => ApplicationHelper::Button::SummaryReload),
  ])
end
