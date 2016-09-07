describe ServiceTemplateLoadBalancer do
  let(:service_template) { FactoryGirl.create(:service_template_load_balancer) }

  context '#create_subtasks' do
    it 'does not need subtasks' do
      expect(service_template.create_subtasks(nil, nil).size).to eq(0)
    end
  end

  context "#load_balancer_manager" do
    let(:ems_amazon) { FactoryGirl.create(:ems_amazon) }

    it "initially reads a nil load_balancer manager" do
      expect(service_template.load_balancer_manager).to be_nil
    end

    it "adds an load_balancer manager" do
      service_template.load_balancer_manager = ems_amazon
      expect(service_template.load_balancer_manager).to eq(ems_amazon)
    end

    it "replaces the existing load_balancer manager" do
      service_template.load_balancer_manager = ems_amazon

      expect(service_template.load_balancer_manager).to eq(ems_amazon)
    end

    it "clears the existing load_balancer manager" do
      service_template.load_balancer_manager = ems_amazon
      service_template.load_balancer_manager = nil

      expect(service_template.load_balancer_manager).to be_nil
    end

    it "clears invalid load_balancer manager" do
      service_template.load_balancer_manager = ems_amazon
      ems_amazon.delete

      service_template.save!
      service_template.reload
      expect(service_template.load_balancer_manager).to be_nil
    end
  end
end
