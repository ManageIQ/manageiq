FactoryBot.define do
  factory :miq_widget_set do
    sequence(:name)         { |n| "widget_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "widget_set_#{seq_padded_for_sorting(n)}" }
  end
end
