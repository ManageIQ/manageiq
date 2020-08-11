# Note:  This example group uses the `subject` defined by the calling spec
shared_examples_for "MiqPolicyMixin" do
  context "MiqPolicyMixin methods" do
    let(:policy) { FactoryBot.create(:miq_policy) }
    let(:policy2) { FactoryBot.create(:miq_policy) }
    let(:policy_set) { FactoryBot.create(:miq_policy_set).tap { |ps| ps.add_member(policy) } }
    let(:policy_set) { FactoryBot.create(:miq_policy_set).tap { |ps| ps.add_member(policy2) } }

    describe "#get_policies" do
      it "supports no policies" do
        expect(subject.get_policies).to eq([])
      end

      it "supports policies" do
        subject.add_policy(policy)
        expect(subject.get_policies).to eq([policy])
      end

      it "supports policy sets" do
        subject.add_policy(policy)
        subject.add_policy(policy2)
        subject.add_policy(policy_set)
        expect(subject.get_policies).to contain_exactly(policy_set, policy, policy2)
      end
    end

    describe "#has_policies" do
      context "with no policies" do
        it "detects no policies in ruby" do
          expect(subject.has_policies?).to eq(false)
        end

        it "detects no policies with preloaded tags in ruby" do
          subject.tags.load
          expect(subject.has_policies?).to eq(false)
        end

        it "detects no policies in SQL" do
          expect(subject.class.select(:id, :has_policies).find(subject.id).has_policies).to be(false)
        end
      end

      context "with a policy" do
        before { subject.add_policy(policy) }

        it "detects policies in ruby" do
          expect(subject.has_policies?).to eq(true)
        end

        it "detects policies with preloaded tags in ruby" do
          subject.tags.load
          expect(subject.has_policies?).to eq(true)
        end

        it "detects policies in SQL" do
          result = subject.class.select(:id, :has_policies).find(subject.id)
          expect(result.has_policies).to be(true)
        end
      end

      context "with a policy_set" do
        before { subject.add_policy(policy_set) }

        it "detects policies in ruby" do
          expect(subject.has_policies?).to eq(true)
        end

        it "detects policies with preloaded tags in ruby" do
          result = subject.class.select(:id, :has_policies).find(subject.id)
          expect(result.has_policies).to be(true)
        end

        it "detects policies in sql" do
          result = subject.class.select(:id, :has_policies).find(subject.id)
          expect(result.has_policies).to be(true)
        end
      end
    end

    describe "#policy_tags" do
      it "supports no policies" do
        expect(subject.policy_tags).to eq([])
      end

      it "supports policies" do
        subject.add_policy(policy)
        expect(subject.policy_tags).to eq(["#{policy.class.name.underscore}/#{policy.id}"])
      end

      it "supports policy sets" do
        subject.add_policy(policy_set)
        expect(subject.policy_tags).to eq(["#{policy_set.class.name.underscore}/#{policy_set.id}"])
      end
    end
  end
end
