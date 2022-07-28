FactoryBot.define do
  factory :physical_storage,
          :class => "::PhysicalStorage" do
    sequence(:name) { |n| "physical_storage_#{seq_padded_for_sorting(n)}" }
    sequence(:ems_ref) { |n| "some-uuid-#{seq_padded_for_sorting(n)}" }
  end
end
