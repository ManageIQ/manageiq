FactoryBot.define do
  factory :request_log do
    message { "Test log message" }
    severity { "INFO" }
  end
end
