describe ServiceTemplateOrchestration do
  subject { FactoryGirl.create(:service_template_orchestration) }

  describe '#create_subtasks' do
    it 'does not need subtasks' do
      expect(subject.create_subtasks(nil, nil).size).to eq(0)
    end
  end

  describe "#orchestration_template" do
    let(:first_orch_template) { FactoryGirl.create(:orchestration_template) }
    let(:second_orch_template) { FactoryGirl.create(:orchestration_template) }

    it "initially reads a nil orchestration template" do
      expect(subject.orchestration_template).to be_nil
    end

    it "adds an orchestration template" do
      subject.orchestration_template = first_orch_template
      expect(subject.orchestration_template).to eq(first_orch_template)
    end

    it "replaces the existing orchestration template" do
      subject.orchestration_template = first_orch_template
      subject.orchestration_template = second_orch_template

      expect(subject.orchestration_template).to eq(second_orch_template)
      expect(subject.orchestration_template).not_to eq(first_orch_template)
    end

    it "clears the existing orchestration template" do
      subject.orchestration_template = first_orch_template
      subject.orchestration_template = nil

      expect(subject.orchestration_template).to be_nil
    end

    it "clears invalid orchestration template" do
      subject.orchestration_template = first_orch_template
      first_orch_template.delete

      subject.save!
      subject.reload
      expect(subject.orchestration_template).to be_nil
    end
  end

  describe "#orchestration_manager" do
    let(:ems_amazon) { FactoryGirl.create(:ems_amazon) }
    let(:ems_openstack) { FactoryGirl.create(:ems_openstack) }

    it "initially reads a nil orchestration manager" do
      expect(subject.orchestration_manager).to be_nil
    end

    it "adds an orchestration manager" do
      subject.orchestration_manager = ems_openstack
      expect(subject.orchestration_manager).to eq(ems_openstack)
    end

    it "replaces the existing orchestration manager" do
      subject.orchestration_manager = ems_openstack
      subject.orchestration_manager = ems_amazon

      expect(subject.orchestration_manager).to eq(ems_amazon)
      expect(subject.orchestration_manager).not_to eq(ems_openstack)
    end

    it "clears the existing orchestration manager" do
      subject.orchestration_manager = ems_openstack
      subject.orchestration_manager = nil

      expect(subject.orchestration_manager).to be_nil
    end

    it "clears invalid orchestration manager" do
      subject.orchestration_manager = ems_amazon
      ems_amazon.delete

      subject.save!
      subject.reload
      expect(subject.orchestration_manager).to be_nil
    end
  end

  describe "#my_zone" do
    context "with orchestration manager" do
      let(:ems_amazon) { FactoryGirl.create(:ems_amazon) }
      before { subject.orchestration_manager = ems_amazon }

      it "takes the zone from orchestration manager" do
        expect(subject.my_zone).to eq(ems_amazon.my_zone)
      end
    end

    context 'without orchestration manager' do
      it "takes the zone from MiqServer" do
        allow(MiqServer).to receive(:my_zone).and_return('default_zone')
        expect(subject.my_zone).to eq('default_zone')
      end
    end
  end
end
