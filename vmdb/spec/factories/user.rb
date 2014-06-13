FactoryGirl.define do
  factory :user do
    userid          "test"
    name            "Test User"
    # encrypted password for password "dummy"
    password_digest "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W"
  end

  factory :user_admin, :parent => :user do
    userid          "admin"
    name            "Administrator"
    miq_groups      { [FactoryGirl.create(:miq_group,
                                          :description   => "EvmGroup-super_administrator",
                                          :miq_user_role => FactoryGirl.create(:miq_user_role,
                                                                               :name => 'EvmRole-super_administrator'
                                                                              ))]
    }
  end
end
