FactoryGirl.define do
  factory :miq_group do
    guid { MiqUUID.new_guid }

    sequence(:description) { |n| "Test Group #{seq_padded_for_sorting(n)}" }
  end

  factory :miq_group_miq_request_approver, :parent => :miq_group do
    miq_user_role { FactoryGirl.create(:miq_user_role_miq_request_approver) }
  end
end
