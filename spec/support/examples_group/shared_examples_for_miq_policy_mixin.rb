# Note:  This example group uses the `subject` defined by the calling spec
shared_examples_for "MiqPolicyMixin" do
  context "MiqPolicyMixin methods" do
    let(:policy) { FactoryBot.create(:miq_policy) }
    let(:policy_set) { FactoryBot.create(:miq_policy_set).tap { |ps| ps.add_member(policy) } }

    describe "#get_policies" do
      it "supports no policies" do
        expect(subject.get_policies).to eq([])
      end

      it "supports policies" do
        subject.add_policy(policy)
        expect(subject.get_policies).to eq([policy])
      end

      it "supports policy sets" do
        subject.add_policy(policy_set)
        expect(subject.get_policies).to eq([policy_set])
      end
    end

    describe "#has_policies" do
      context "with no policies" do
        it "detects no policies in ruby" do
          expect(subject.has_policies?).to eq(false)
        end
      end

      context "with a policy" do
        before { subject.add_policy(policy) }

        it "detects policies in ruby" do
          expect(subject.has_policies?).to eq(true)
        end
      end

      context "with a policy_set" do
        before { subject.add_policy(policy_set) }

        it "detects policies in ruby" do
          expect(subject.has_policies?).to eq(true)
        end
      end
    end
  end
end
