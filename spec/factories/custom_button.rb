FactoryGirl.define do
  factory :custom_button do
    sequence(:name)        { |n| "custom_button_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "custom_button_#{seq_padded_for_sorting(n)}" }

    trait :with_resource_action_dialog do
      resource_action { FactoryGirl.create(:resource_action, :dialog_id => FactoryGirl.create(:dialog).id) }
    end
  end
end
