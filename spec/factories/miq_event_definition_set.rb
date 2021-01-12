FactoryBot.define do
  factory :miq_event_definition_set do
    transient { events { nil } }
    sequence(:name)         { |n| "event_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "event_set_#{seq_padded_for_sorting(n)}" }

    after(:create) do |event_set, builder|
      if builder.events
        builder.events.each do |event|
          event_set.add_member(event)
        end
      end
    end
  end
end
