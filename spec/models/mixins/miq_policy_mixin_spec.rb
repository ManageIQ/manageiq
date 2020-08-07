describe MiqPolicyMixin do
  let(:policy) { FactoryBot.create(:miq_policy) }
  let(:policy_set) { FactoryBot.create(:miq_policy_set).tap { |ps| ps.add_member(policy) } }
  subject { TestModel.create }

  before do
    class TestModel < ApplicationRecord
      self.table_name = "hosts" # any table really
      acts_as_miq_taggable
      include MiqPolicyMixin
    end
  end

  after do
    Object.send(:remove_const, :TestModel)
  end

  include_examples "MiqPolicyMixin"
end
