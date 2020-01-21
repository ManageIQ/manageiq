FactoryBot.define do
  factory :custom_button do
    sequence(:name)        { |n| "custom_button_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "custom_button_#{seq_padded_for_sorting(n)}" }

    trait :with_resource_action_dialog do
      resource_action { FactoryBot.create(:resource_action, :dialog_id => FactoryBot.create(:dialog).id) }
    end
  end
end
