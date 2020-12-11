FactoryBot.define do
  factory :miq_widget_set do
    sequence(:name)         { |n| "widget_set_#{seq_padded_for_sorting(n)}" }
    sequence(:description)  { |n| "widget_set_#{seq_padded_for_sorting(n)}" }

    trait :set_data_with_one_widget do
      set_data do
        {:col1             => [FactoryBot.create(:miq_widget).id],
         :reset_upon_login => false,
         :locked           => false}
      end
    end

    before(:create) do |x|
      x.group_id = x.owner_id if x.owner_id
    end
  end
end
