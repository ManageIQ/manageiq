FactoryGirl.define do
  factory :user do
    # HACK: Due to password_digest callback needing infrastructure to write out
    #       the new password to disk.
    before(:create) do
      MiqRegion.seed
    end

    userid          "test"
    name            "Test User"

    # encrypted password for "dummy"
    password_digest "$2a$10$FTbGT/y/PQ1HvoOoc1FcyuuTtHzfop/uG/mcEAJLYpzmsUIJcGT7W"
  end

  factory :user_admin, :parent => :user do
    userid          "admin"
    name            "Administrator"
    miq_groups      { [FactoryGirl.create(:miq_group,
                                          :description   => "EvmGroup-super_administrator",
                                          :miq_user_role => FactoryGirl.create(:miq_user_role,
                                                                               :name => 'EvmRole-super_administrator'
                                                                              ))]}
  end

  factory :user_miq_request_approver, :parent => :user do
    sequence(:name)   { |n| "Request Approver #{seq_padded_for_sorting(n)}" }
    sequence(:userid) { |n| "request_approver_#{seq_padded_for_sorting(n)}" }

    miq_groups { [FactoryGirl.create(:miq_group_miq_request_approver)] }
  end
end
