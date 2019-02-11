FactoryBot.define do
  factory :storage_file do
    sequence(:name)  { |n| "path/to/file#{seq_padded_for_sorting(n)}/file#{n}.log" }
    vm_or_template_id    { 1000 }
  end
end
