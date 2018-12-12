describe CiFeatureMixin do
  let(:service) { FactoryBot.create(:service) }
  describe "#retireable?" do
    it "vm is retireable" do
      FactoryBot.create(:service_resource, :service => service, :resource => FactoryBot.create(:vm))

      expect(service.service_resources.first.resource.retireable?).to eq(true)
    end

    it "orchestration stack is retireable" do
      FactoryBot.create(:service_resource, :service => service, :resource => FactoryBot.create(:orchestration_stack_amazon))

      expect(service.service_resources.first.resource.retireable?).to eq(true)
    end

    it "job not retireable" do
      FactoryBot.create(:service_resource, :service => service, :resource => FactoryBot.create(:embedded_ansible_job))

      expect(service.service_resources.first.resource.retireable?).to eq(false)
    end

    context "service" do
      context "with type" do
        let(:service1) { FactoryBot.create(:service_ansible_tower, :type => ServiceAnsibleTower) }
        it "is retireable" do
          FactoryBot.create(:service_resource, :service => service, :resource => service1)

          expect(service.service_resources.first.resource.retireable?).to eq(true)
        end
      end

      context "without type" do
        it "is not retireable" do
          FactoryBot.create(:service_resource, :service => service, :resource => FactoryBot.create(:service))

          expect(service.service_resources.first.resource.retireable?).to eq(false)
        end
      end
    end
  end
end
