FactoryBot.define do
  factory :configuration_profile

  factory :configuration_profile_foreman,
          :aliases => ["manageiq/providers/foreman/configuration_manager/configuration_profile"],
          :class   => "ManageIQ::Providers::Foreman::ConfigurationManager::ConfigurationProfile",
          :parent  => :configuration_profile do
    name { "foreman config profile" }
  end
end
