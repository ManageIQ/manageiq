FactoryBot.define do
  factory :git_reference do
    sequence(:name) { |n| "git_ref#{seq_padded_for_sorting(n)}" }
  end

  factory :git_branch, :parent => :git_reference, :class => "GitBranch" do
    sequence(:name) { |n| "git_branch#{seq_padded_for_sorting(n)}" }
  end

  factory :git_tag, :parent => :git_reference, :class => "GitTag" do
    sequence(:name) { |n| "git_tag#{seq_padded_for_sorting(n)}" }
  end
end
