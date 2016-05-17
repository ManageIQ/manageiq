FactoryGirl.define do
  factory :middleware_server do
    sequence(:name) { |n| "middleware_server_#{seq_padded_for_sorting(n)}" }
  end

  factory :hawkular_middleware_server,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_server'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareServer',
          :parent  => :middleware_server do
  end
end
