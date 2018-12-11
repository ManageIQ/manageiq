FactoryBot.define do
  factory :rss_feed do
    sequence(:name) { |n| "feed_#{seq_padded_for_sorting(n)}" }
  end
end
