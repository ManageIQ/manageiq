module MiqAeServiceGenericObjectSpec
  describe MiqAeMethodService::MiqAeServiceGenericObject do
    let(:generic_object)   { FactoryGirl.create(:generic_object) }
    let(:service_go)       { MiqAeMethodService::MiqAeServiceGenericObject.find(generic_object.id) }
    let(:service)          { FactoryGirl.create(:service) }
    let(:service_service)  { MiqAeMethodService::MiqAeServiceService.find(service.id) }
    let(:service2)         { FactoryGirl.create(:service) }
    let(:service_service2) { MiqAeMethodService::MiqAeServiceService.find(service2.id) }

    context "#add_to_service" do
      it "adds a generic object to service_resources of a valid service" do
        service_go.add_to_service(service_service)
        assert_service_resource(service, generic_object)
      end

      it "adds a generic object to multiple services" do
        service_go.add_to_service(service_service)
        service_go.add_to_service(service_service2)

        assert_service_resource(service, generic_object)
        assert_service_resource(service2, generic_object)
      end

      it "raises an error when adding a generic object to an invalid service" do
        expect { service_go.add_to_service('wrong type') }
          .to raise_error(ArgumentError, /service must be a MiqAeServiceService/)
      end
    end

    context "#remove_from_service" do
      it "removes a generic object from a connected service" do
        service_go.add_to_service(service_service)
        expect(service.service_resources.count).to eq(1)

        service_go.remove_from_service(service_service)
        expect(service.service_resources.count).to eq(0)
      end

      it "removes a generic object from multiple connected service" do
        service_go.add_to_service(service_service)
        service_go.add_to_service(service_service2)
        assert_service_resource(service, generic_object)
        assert_service_resource(service2, generic_object)

        service_go.remove_from_service(service_service)
        expect(service.service_resources.count).to  eq(0)
        expect(service2.service_resources.count).to eq(1)
      end

      it "raises an error when adding a generic object to an invalid service" do
        expect { service_go.remove_from_service('wrong type') }
          .to raise_error(ArgumentError, /service must be a MiqAeServiceService/)
      end
    end

    def assert_service_resource(service, resource)
      expect(service.service_resources[0].resource_id).to   eq(resource.id)
      expect(service.service_resources[0].resource_type).to eq(resource.class.name)
    end
  end
end
