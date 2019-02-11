FactoryBot.define do
  factory :miq_widget do
    sequence(:title)        { |n| "widget_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "widget_#{seq_padded_for_sorting(n)}" }
    content_type            { "report" }
  end
end
