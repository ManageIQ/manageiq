FactoryBot.define do
  factory :middleware_server do
    sequence(:name) { |n| "middleware_server_#{seq_padded_for_sorting(n)}" }
    sequence(:feed) { |n| "feed_#{n}" }
  end

  factory :hawkular_middleware_server,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_server'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer',
          :parent  => :middleware_server

  factory :hawkular_middleware_server_wildfly,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_server_wildfly'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServerWildfly',
          :parent  => :middleware_server

  factory :hawkular_middleware_server_eap,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_server_eap'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServerEap',
          :parent  => :hawkular_middleware_server_wildfly
end
