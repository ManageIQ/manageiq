describe CiFeatureMixin do
  let(:service) { FactoryGirl.create(:service) }
  describe "#retireable?" do
    it "vm is retireable" do
      FactoryGirl.create(:service_resource, :service => service, :resource => FactoryGirl.create(:vm))

      expect(service.service_resources.first.resource.retireable?).to eq(true)
    end

    it "orchestration stack is retireable" do
      FactoryGirl.create(:service_resource, :service => service, :resource => FactoryGirl.create(:orchestration_stack_amazon))

      expect(service.service_resources.first.resource.retireable?).to eq(true)
    end

    it "job not retireable" do
      FactoryGirl.create(:service_resource, :service => service, :resource => FactoryGirl.create(:embedded_ansible_job))

      expect(service.service_resources.first.resource.retireable?).to eq(false)
    end

    it "service is retireable" do
      FactoryBot.create(:service_resource, :service => service, :resource => FactoryBot.create(:service_ansible_tower, :type => ServiceAnsibleTower))

      expect(service.service_resources.first.resource.retireable?).to eq(true)
    end
  end
end
