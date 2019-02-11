FactoryBot.define do
  factory :log_file do
    state       { "collecting" }
    historical  { true }
    description { "Default logfile" }
  end
end
