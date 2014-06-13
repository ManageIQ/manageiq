FactoryGirl.define do
  factory :miq_database do
    session_secret_token  { SecureRandom.hex(64) }
    csrf_secret_token     { SecureRandom.hex(64) }
    update_repo_name      "cf-me-5.2-for-rhel-6-rpms"
  end
end
