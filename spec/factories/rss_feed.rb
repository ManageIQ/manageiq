FactoryGirl.define do
  factory :rss_feed do
    sequence(:name) { |num| "rss_feed_#{num}" }
    description     "Test Rss Feed"
  end
end
