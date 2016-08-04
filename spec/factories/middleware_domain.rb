FactoryGirl.define do
  factory :middleware_domain do
    sequence(:name) { |n| "middleware_domain_#{seq_padded_for_sorting(n)}" }
  end

  factory :hawkular_middleware_domain,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_domain'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareDomain',
          :parent  => :middleware_domain do
  end
end
