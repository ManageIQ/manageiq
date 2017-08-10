FactoryGirl.define do
  factory :miq_provision_request do
    source { create(:miq_template) }
  end
end
