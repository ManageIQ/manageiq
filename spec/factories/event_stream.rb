FactoryBot.define do
  factory :event_stream
  factory :ems_event,
          :class  => "EmsEvent",
          :parent => :event_stream
  factory :miq_event,
          :class  => "MiqEvent",
          :parent => :event_stream
end
