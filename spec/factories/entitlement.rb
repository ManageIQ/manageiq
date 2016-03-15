FactoryGirl.define do
  factory :entitlement do
    transient do
      features nil
      role nil
    end

    after :build do |entitlement, e|
      if e.role || e.features
        entitlement.miq_user_role = FactoryGirl.create(:miq_user_role,
                                                       :features => e.features,
                                                       :role     => e.role)
      end
    end
  end
end
