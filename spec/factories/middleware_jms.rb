FactoryGirl.define do
  factory :middleware_jms do
  end

  factory :hawkular_middleware_jms,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_jms'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareJms',
          :parent  => :middleware_jms do
  end

  factory :hawkular_middleware_jms_initialized,
          :parent => :hawkular_middleware_jms do
    name 'JMS Queue [DLQ]'
    nativeid 'Local~/subsystem=messaging-activemq/server=default/jms-queue=DLQ'
  end
end
