describe ServiceTemplateOrchestration do
  let(:service_template) { FactoryGirl.create(:service_template_orchestration) }

  context '#create_subtasks' do
    it 'does not need subtasks' do
      expect(service_template.create_subtasks(nil, nil).size).to eq(0)
    end
  end

  context "#orchestration_template" do
    let(:first_orch_template) { FactoryGirl.create(:orchestration_template) }
    let(:second_orch_template) { FactoryGirl.create(:orchestration_template) }

    it "initially reads a nil orchestration template" do
      expect(service_template.orchestration_template).to be_nil
    end

    it "adds an orchestration template" do
      service_template.orchestration_template = first_orch_template
      expect(service_template.orchestration_template).to eq(first_orch_template)
    end

    it "replaces the existing orchestration template" do
      service_template.orchestration_template = first_orch_template
      service_template.orchestration_template = second_orch_template

      expect(service_template.orchestration_template).to eq(second_orch_template)
      expect(service_template.orchestration_template).not_to eq(first_orch_template)
    end

    it "clears the existing orchestration template" do
      service_template.orchestration_template = first_orch_template
      service_template.orchestration_template = nil

      expect(service_template.orchestration_template).to be_nil
    end

    it "clears invalid orchestration template" do
      service_template.orchestration_template = first_orch_template
      first_orch_template.delete

      service_template.save!
      service_template.reload
      expect(service_template.orchestration_template).to be_nil
    end
  end

  context "#orchestration_manager" do
    let(:ems_amazon) { FactoryGirl.create(:ems_amazon) }
    let(:ems_openstack) { FactoryGirl.create(:ems_openstack) }

    it "initially reads a nil orchestration manager" do
      expect(service_template.orchestration_manager).to be_nil
    end

    it "adds an orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      expect(service_template.orchestration_manager).to eq(ems_openstack)
    end

    it "replaces the existing orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      service_template.orchestration_manager = ems_amazon

      expect(service_template.orchestration_manager).to eq(ems_amazon)
      expect(service_template.orchestration_manager).not_to eq(ems_openstack)
    end

    it "clears the existing orchestration manager" do
      service_template.orchestration_manager = ems_openstack
      service_template.orchestration_manager = nil

      expect(service_template.orchestration_manager).to be_nil
    end

    it "clears invalid orchestration manager" do
      service_template.orchestration_manager = ems_amazon
      ems_amazon.delete

      service_template.save!
      service_template.reload
      expect(service_template.orchestration_manager).to be_nil
    end
  end
end
