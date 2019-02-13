FactoryBot.define do
  factory :account

  factory :account_user, :parent => :account do
    name { 'bob' }
    acctid { 10 }
    homedir { '/dev/null' }
    accttype { 'user' }
  end

  factory :account_group, :parent => :account do
    name { 'monsters' }
    acctid { 175 }
    accttype { 'group' }
  end
end
