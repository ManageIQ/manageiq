FactoryBot.define do
  factory(:category) do
    sequence(:name)        { |n| "category_#{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "category #{seq_padded_for_sorting(n)}" }
  end
end
