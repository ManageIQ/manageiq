FactoryBot.define do
  factory :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_namespace_#{seq_padded_for_sorting(n)}" }

    before(:create) do |ns, evaluator|
      if evaluator.domain_id
        ns.parent_id ||= evaluator.domain_id
      elsif evaluator.domain
        ns.parent ||= evaluator.domain
      else
        ns.parent ||= FactoryBot.create(:miq_ae_domain)
      end
    end
  end
end
