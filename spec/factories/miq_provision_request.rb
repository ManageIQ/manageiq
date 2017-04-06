FactoryGirl.define do
  factory :miq_provision_request do
    requester { create(:user) }
    source { create(:miq_template) }
  end
end
