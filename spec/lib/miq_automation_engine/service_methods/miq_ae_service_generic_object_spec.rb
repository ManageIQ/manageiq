module MiqAeServiceGenericObjectSpec
  describe MiqAeMethodService::MiqAeServiceGenericObject do
    let(:generic_object)   { FactoryGirl.create(:generic_object) }
    let(:service_go)       { MiqAeMethodService::MiqAeServiceGenericObject.find(generic_object.id) }
    let(:service)          { FactoryGirl.create(:service) }
    let(:service_service)  { MiqAeMethodService::MiqAeServiceService.find(service.id) }
    let(:service2)         { FactoryGirl.create(:service) }
    let(:service_service2) { MiqAeMethodService::MiqAeServiceService.find(service2.id) }

    describe "#add_to_service" do
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

    describe "#remove_from_service" do
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

    describe '#convert_params_to_ar_model' do
      let(:user) { FactoryGirl.create(:user_with_group) }
      subject    { service_go.send(:convert_params_to_ar_model, @args) }

      before do
        allow(DRb).to receive_message_chain('front.workspace.ae_user').and_return(user)
      end

      context 'converts service model object to AR object' do
        it 'with a single value' do
          @args = service_service
          expect(subject).to eq(service)
        end

        it 'with an array' do
          @args = [service_service, service_service2]
          expect(subject).to match_array([service, service2])
        end

        it 'with a hash' do
          @args = { :services => [service_service, service_service2] }
          expect(subject).to eq(:services => [service, service2])
        end
      end

      context 'does not touch non-service model object' do
        it 'with a single value' do
          @args = service
          expect(subject).to eq(service)
        end

        it 'with an array' do
          @args = [service, service2]
          expect(subject).to eq(@args)
        end

        it 'with a hash' do
          @args = { :services => [service, service2] }
          expect(subject).to eq(@args)
        end
      end
    end

    def assert_service_resource(service, resource)
      expect(service.service_resources[0].resource_id).to   eq(resource.id)
      expect(service.service_resources[0].resource_type).to eq(resource.class.name)
    end
  end
end
