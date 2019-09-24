FactoryBot.define do
  factory :miq_queue do
    state  { 'ready' }
    args   { [] }
  end
end
