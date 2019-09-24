FactoryBot.define do
  factory :middleware_messaging

  factory :hawkular_middleware_messaging,
          :aliases => ['app/models/manageiq/providers/hawkular/middleware_manager/middleware_messaging'],
          :class   => 'ManageIQ::Providers::Hawkular::MiddlewareManager::MiddlewareMessaging',
          :parent  => :middleware_messaging

  factory :hawkular_middleware_messaging_initialized,
          :parent => :hawkular_middleware_messaging do
    name { 'JMS Queue [DLQ]' }
    nativeid { 'Local~/subsystem=messaging-activemq/server=default/jms-queue=DLQ' }
  end

  factory :hawkular_middleware_messaging_initialized_queue,
          :parent => :hawkular_middleware_messaging do
    name { 'JMS Queue [DLQ]' }
    nativeid { 'Local~/subsystem=messaging-activemq/server=default/jms-queue=DLQ' }
  end

  factory :hawkular_middleware_messaging_initialized_topic,
          :parent => :hawkular_middleware_messaging do
    name { 'JMS Topic [HawkularAlertData]' }
    nativeid { 'Local~/subsystem=messaging-activemq/server=default/jms-topic=HawkularAlertData' }
  end
end
