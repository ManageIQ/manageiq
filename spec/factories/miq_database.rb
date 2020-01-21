FactoryBot.define do
  factory :miq_database do
    session_secret_token  { SecureRandom.hex(64) }
    csrf_secret_token     { SecureRandom.hex(64) }
  end
end
