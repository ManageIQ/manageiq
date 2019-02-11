FactoryBot.define do
  sequence(:miq_user_role_name) { |n| "UserRole #{seq_padded_for_sorting(n)}" }

  factory :miq_user_role do
    transient do
      # e.g.: miq_request_approval
      features { nil }
      # e.g.: super_administrator
      role { nil }
    end

    name { |ur| ur.role ? "EvmRole-#{ur.role}" : generate(:miq_user_role_name) }

    after(:build) do |user, evaluator|
      e_features = evaluator.features
      if evaluator.role.present?
        @system_roles ||= YAML.load_file(MiqUserRole::FIXTURE_YAML)
        seeded_role = @system_roles.detect { |role| role[:name] == "EvmRole-#{evaluator.role}" }

        if seeded_role.present?
          user.read_only = seeded_role[:read_only]
          user.settings = seeded_role[:settings]
        end
        if e_features.blank?
          # admins now using a feature instead of a roll
          if evaluator.role == "super_administrator"
            e_features = MiqProductFeature::SUPER_ADMIN_FEATURE
          end
        end
      end

      if e_features.present?
        user.miq_product_features = Array.wrap(e_features).map do |f|
          if f.kind_of?(MiqProductFeature) # TODO: remove class reference
            f
          else
            MiqProductFeature.find_by(:identifier => f) || FactoryBot.create(:miq_product_feature, :identifier => f)
          end
        end
      end
    end
  end
end
