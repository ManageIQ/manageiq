shared_examples_for "ComplianceMixin" do
  context "ComplianceMixin methods" do
    let(:towhat) { subject.class.base_model.name.gsub(/.*template.*/i, "Vm") }
    let(:action) { FactoryBot.create(:miq_action) }
    let(:event)  { FactoryBot.create(:miq_event_definition, :name => "#{towhat.downcase}_compliance_check") }
    let(:policy) do
      FactoryBot.create(:miq_policy, :active => true, :towhat => towhat, :mode => 'compliance').tap do |p|
        p.replace_actions_for_event(event, [[action, {:qualifier => :success}]])
      end
    end

    describe "#has_compliance_policies?" do
      it 'detects no policies' do
        expect(subject.has_compliance_policies?).to be false
      end

      it 'detects policies' do
        subject.add_policy(policy)
        expect(subject.has_compliance_policies?).to be true
      end
    end

    describe "#compliance_policies" do
      it 'detects policies' do
        subject.add_policy(policy)
        expect(subject.compliance_policies).to eq([policy])
      end
    end
  end
end
