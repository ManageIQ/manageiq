FactoryBot.define do
  factory :pxe_server do
    sequence(:name) { |n| "pxe_server_#{seq_padded_for_sorting(n)}" }
    sequence(:uri)  { |n| "http://test.example.com/pxe_server_#{seq_padded_for_sorting(n)}" }
  end
end
