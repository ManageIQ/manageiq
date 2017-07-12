module MiqAeServiceLoadBalancerSpec
  describe MiqAeMethodService::MiqAeServiceLoadBalancer do
    let(:load_balancer)         { FactoryGirl.create(:load_balancer) }
    let(:service_load_balancer) { MiqAeMethodService::MiqAeServiceLoadBalancer.find(load_balancer.id) }
    let(:service)               { FactoryGirl.create(:service) }
    let(:service_service)       { MiqAeMethodService::MiqAeServiceService.find(service.id) }

    context "#add_to_service" do
      it "adds a load_balancer to service_resources of a valid service" do
        service_load_balancer.add_to_service(service_service)
        expect(service.service_resources[0].resource_id).to eq(load_balancer.id)
        expect(service.service_resources[0].resource_type).to eq(load_balancer.class.name)
      end

      it "raises an error when adding a load_balancer to an invalid service" do
        expect { service_load_balancer.add_to_service('wrong type') }
          .to raise_error(ArgumentError, /service must be a MiqAeServiceService/)
      end
    end

    context "normalized_live_status" do
      it "gets the live status of the load_balancer and normalizes the status" do
        allow_any_instance_of(LoadBalancer).to receive(:raw_status) { 'creating' }

        expect(service_load_balancer.normalized_live_status).to eq('creating')
      end

      it "shows the status as not_exist for non-existing load_balancers" do
        allow_any_instance_of(LoadBalancer).to receive(:raw_status) { raise MiqException::MiqLoadBalancerNotExistError, 'test failure' }

        expect(service_load_balancer.normalized_live_status).to eq(['not_exist', 'test failure'])
      end
    end
  end
end
