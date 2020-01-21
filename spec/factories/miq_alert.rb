FactoryBot.define do
  factory :miq_alert do
    sequence(:description) { |n| "Test Alert #{n}" }
    enabled         { true }
  end

  factory :miq_alert_vm, :parent => :miq_alert do
    options         { { :notifications => {} } }
    db              { "Vm" }
  end

  factory :miq_alert_host, :parent => :miq_alert do
    options         { { :notifications => {} } }
    db              { "Host" }
  end
end
