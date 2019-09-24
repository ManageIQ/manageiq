FactoryBot.define do
  factory :database_backup do
    sequence(:name)  { |val| "db_backup_#{val}" }
  end
end
