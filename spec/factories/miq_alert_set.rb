FactoryBot.define do
  factory :miq_alert_set do
    transient { alerts { nil } }
    sequence(:name)         { |n| "alert_profile_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "alert_profile_#{seq_padded_for_sorting(n)}" }

    after(:create) do |alert_set, builder|
      if builder.alerts
        builder.alerts.each do |alert|
          alert_set.add_member(alert)
        end
      end
    end
  end

  factory :miq_alert_set_vm, :parent => :miq_alert_set do
    mode { "VmOrTemplate" } # VmOrTemplate.base_model.name
  end

  factory :miq_alert_set_host, :parent => :miq_alert_set do
    mode { "Host" } # Host.base_model.name
  end
end
