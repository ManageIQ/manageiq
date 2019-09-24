FactoryBot.define do
  factory :vim_performance_state, :class => :VimPerformanceState do
    timestamp { Time.now.utc }
    state_data {{}}
  end
end
