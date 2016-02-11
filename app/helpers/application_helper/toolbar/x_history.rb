class ApplicationHelper::Toolbar::XHistory < ApplicationHelper::Toolbar::Basic
  button_group('history_main', [
    select(
      :history_choice,
      'fa fa-arrow-left fa-lg',
      N_('History'),
      nil,
      :items => [
        button(
          :history_1,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=1"),
        button(
          :history_2,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=2"),
        button(
          :history_3,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=3"),
        button(
          :history_4,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=4"),
        button(
          :history_5,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=5"),
        button(
          :history_6,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=6"),
        button(
          :history_7,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=7"),
        button(
          :history_8,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=8"),
        button(
          :history_9,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=9"),
        button(
          :history_10,
          'fa fa-arrow-left fa-lg',
          N_('Go to this item'),
          nil,
          :url => "x_history?item=10"),
      ]
    ),
    button(
      :summary_reload,
      'fa fa-repeat fa-lg',
      N_('Reload current display'),
      nil,
      :url => "reload"),
  ])
end
