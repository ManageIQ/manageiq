# Create a small environment for Redhat
FactoryBot.define do
  factory :environment_redhat, class: OpenStruct do
    zone { FactoryBot.build(:zone, :name => "ozone") }
    ems  { FactoryBot.build(:ems_redhat, :zone => zone, :api_version => '4.2.4') }

    transient do
      num_host { 1 }
    end

    after(:build) do |env, evaluator|
      env.ems.hosts = FactoryBot.build_list(:host_redhat, evaluator.num_host)
    end
  end
end
