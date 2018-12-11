FactoryBot.define do
  factory :service_template_catalog do
    sequence(:name)  { |num| "service_template_catalog_#{num}" }
  end
end
