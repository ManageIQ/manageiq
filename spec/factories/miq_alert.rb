FactoryGirl.define do
  factory :miq_alert do
    description     "Test Alert"
  end

  factory :miq_alert_vm, :class => :MiqAlert do
    options         :notifications => {}
    db              "Vm"
  end
end
