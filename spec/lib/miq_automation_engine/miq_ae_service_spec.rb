require "spec_helper"

module MiqAeServiceSpec
  include MiqAeMethodService

  describe MiqAeServiceObject do
    before do
      @object = double('object')
      @service = double('service')
      @service_object = MiqAeServiceObject.new(@object, @service)
    end

    context "#attributes" do
      before do
        @object.stub(:attributes).and_return('true'     => true,
                                             'false'    => false,
                                             'time'     => Time.parse('Aug 30, 2013'),
                                             'symbol'   => :symbol,
                                             'int'      => 1,
                                             'float'    => 1.1,
                                             'string'   => 'hello',
                                             'array'    => [1, 2, 3, 4],
                                             'password' => MiqAePassword.new('test'))
      end

      it "obscures passwords" do
        original_attributes = @object.attributes.dup
        attributes = @service_object.attributes
        attributes['password'].should == '********'
        @object.attributes.should == original_attributes
      end
    end

    context "#inspect" do
      it "returns the class, id and name" do
        @object.stub(:object_name).and_return('fred')
        regex = /#<MiqAeMethodService::MiqAeServiceObject:0x(\w+) name:.\"(?<name>\w+)\">/
        match = regex.match(@service_object.inspect)
        match[:name].should eq('fred')
      end
    end
  end

  describe MiqAeService do
    context "#service_model" do
      let(:miq_ae_service) { MiqAeService.new(double('ws', :persist_state_hash => {})) }
      let(:prefix) { "MiqAeMethodService::MiqAeService" }

      it "loads base model" do
        expect(miq_ae_service.service_model(:VmOrTemplate)).to   be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
        expect(miq_ae_service.service_model(:vm_or_template)).to be(MiqAeMethodService::MiqAeServiceVmOrTemplate)
      end

      it "loads sub-classed model" do
        expect(miq_ae_service.service_model(:Vm)).to be(MiqAeMethodService::MiqAeServiceVm)
        expect(miq_ae_service.service_model(:vm)).to be(MiqAeMethodService::MiqAeServiceVm)
      end

      it "loads model with mapped name" do
        expect(miq_ae_service.service_model(:ems)).to be(MiqAeMethodService::MiqAeServiceExtManagementSystem)
      end

      it "loads name-spaced model by mapped name" do
        expect(miq_ae_service.service_model(:ems_openstack)).to be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
        expect(miq_ae_service.service_model(:vm_openstack)).to  be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
      end

      it "loads name-spaced model by fully-qualified name" do
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager)).to    be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager)
        expect(miq_ae_service.service_model(:ManageIQ_Providers_Openstack_CloudManager_Vm)).to be(
          MiqAeMethodService::MiqAeServiceManageIQ_Providers_Openstack_CloudManager_Vm)
      end

      it "raises error on invalid service_model name" do
        expect { miq_ae_service.service_model(:invalid_model) }.to raise_error(NameError)
      end

      it "loads all mapped models" do
        MiqAeMethodService::MiqAeService::LEGACY_MODEL_NAMES.values.each do |model_name|
          expect { "MiqAeMethodService::MiqAeService#{model_name}".constantize }.to_not raise_error
        end
      end

      it "loads cloud networks" do
        items = %w(
          ManageIQ_Providers_Openstack_CloudManager_CloudNetwork
          ManageIQ_Providers_Openstack_CloudManager_CloudNetwork_Private
          ManageIQ_Providers_Openstack_CloudManager_CloudNetwork_Public
          ManageIQ_Providers_Openstack_InfraManager_CloudNetwork
          ManageIQ_Providers_Openstack_InfraManager_CloudNetwork_Private
          ManageIQ_Providers_Openstack_InfraManager_CloudNetwork_Public
        )
        items.each do |name|
          expect(miq_ae_service.vmdb(name)).to be("#{prefix}#{name}".constantize)
        end
      end
    end
  end
end
