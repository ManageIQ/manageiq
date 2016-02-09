class ApplicationHelper::Toolbar::XHistory < ApplicationHelper::Toolbar::Basic
  button_group('history_main', [
    {
      :buttonSelect => "history_choice",
      :icon         => "fa fa-arrow-left fa-lg",
      :title        => N_("History"),
      :items => [
        {
          :button       => "history_1",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=1",
        },
        {
          :button       => "history_2",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=2",
        },
        {
          :button       => "history_3",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=3",
        },
        {
          :button       => "history_4",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=4",
        },
        {
          :button       => "history_5",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=5",
        },
        {
          :button       => "history_6",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=6",
        },
        {
          :button       => "history_7",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=7",
        },
        {
          :button       => "history_8",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=8",
        },
        {
          :button       => "history_9",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=9",
        },
        {
          :button       => "history_10",
          :icon         => "fa fa-arrow-left fa-lg",
          :title        => N_("Go to this item"),
          :url          => "x_history?item=10",
        },
      ]
    },
    {
      :button       => "summary_reload",
      :icon         => "fa fa-repeat fa-lg",
      :title        => N_("Reload current display"),
      :url          => "reload",
    },
  ])
end
