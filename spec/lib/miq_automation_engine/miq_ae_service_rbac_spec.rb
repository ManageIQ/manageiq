include AutomationSpecHelper
require 'drb'
module MiqAeServiceModelSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVmOrTemplate do
    before do
      vm11
      vm21
      user1
      user2
    end

    let(:options) { {} }

    let(:default_tenant) { Tenant.seed }

    let(:tenant1) { FactoryGirl.create(:tenant) }
    let(:group1) { FactoryGirl.create(:miq_group, :tenant => tenant1) }
    let(:ems1)   { FactoryGirl.create(:ext_management_system, :tenant => tenant1) }
    let(:host1)   { FactoryGirl.create(:host) }
    let(:user1) { FactoryGirl.create(:user, :miq_groups => [group1], :settings => {:display => {:timezone => "UTC"}}) }
    let(:vm11) { FactoryGirl.create(:vm_vmware, :tenant => tenant1, :host => host1, :miq_group => group1) }
    let(:vm12) { FactoryGirl.create(:vm_vmware, :tenant => tenant1, :host => host1, :miq_group => group1) }
    let(:vm13) { FactoryGirl.create(:vm_vmware, :tenant => tenant1, :host => host1, :miq_group => group1) }

    let(:tenant2) { FactoryGirl.create(:tenant) }
    let(:group2) { FactoryGirl.create(:miq_group, :tenant => tenant2) }
    let(:user2) { FactoryGirl.create(:user, :miq_groups => [group2], :settings => {:display => {:timezone => "UTC"}}) }
    let(:ems2) { FactoryGirl.create(:ext_management_system, :tenant => tenant2) }
    let(:host2) { FactoryGirl.create(:host) }
    let(:vm21) { FactoryGirl.create(:vm_vmware, :tenant => tenant2, :host => host2, :miq_group => group2) }
    let(:vm22) { FactoryGirl.create(:vm_vmware, :tenant => tenant2, :host => host2, :miq_group => group2) }
    let(:vm23) { FactoryGirl.create(:vm_vmware, :tenant => tenant2, :host => host2, :miq_group => group2) }

    context "enable rbac" do
      before do
        @workspace = double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options)
        @workspace_class =  class_double("MiqAeEngine::MiqAeWorkspaceRuntime")
        @front  =  MiqAeMethodService::MiqAeServiceFront.new(@workspace)
        allow(@workspace).to receive(:rbac_enabled?).and_return(true)
        allow(@workspace).to receive(:rbac=)
        allow(@workspace_class).to receive(:current).and_return(@workspace)
        allow(DRb).to receive(:front).and_return(@front)
        allow(@workspace).to receive(:ae_user).and_return(user1)
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end

      it 'cannot access other tenants vm by id' do
        expect do
          MiqAeMethodService::MiqAeServiceVmOrTemplate.new(vm21.id)
        end.to raise_error(MiqAeException::ServiceNotFound)
      end

      it 'can access other tenants vm object given the object' do
        obj = MiqAeMethodService::MiqAeServiceVmOrTemplate.new(vm21)
        expect(obj.id).to eq(vm21.id)
      end

      it 'can access current users vm' do
        svc_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.new(vm11.id)
        expect(svc_vm.name).to eq(vm11.name)
      end

      it 'access a vm by name' do
        svc_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.find_by_name(vm11.name)
        expect(svc_vm.id).to eq(vm11.id)
      end

      it 'get all vms per tenant' do
        vm12
        vm13
        vm22
        vm23
        all_vms = MiqAeMethodService::MiqAeServiceVmOrTemplate.all
        ids = [vm11.id, vm12.id, vm13.id]
        expect(all_vms.collect(&:id)).to match_array(ids)
      end

      it 'get count of vms per tenant' do
        vm12
        vm13
        vm22
        vm23
        count = MiqAeMethodService::MiqAeServiceVmOrTemplate.count
        expect(count).to eq(3)
      end

      it 'get first vm from a tenant' do
        vm12
        vm13
        vm22
        vm23
        first_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.first
        ids = [vm11.id, vm12.id, vm13.id]
        expect(ids.include?(first_vm.id)).to be_truthy
      end

      it 'get vms connected to a host' do
        vm12
        vm13
        vm22
        vm23
        host = MiqAeMethodService::MiqAeServiceHost.first
        expect(host.id).to eq(host1.id)
        ids = [vm11.id, vm12.id, vm13.id]
        expect(host.vms.collect(&:id)).to match_array(ids)
      end

      it 'where, to fetch an inaccessible vm' do
        svc_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.where("name = ?", vm21.name).first
        expect(svc_vm).to eq(nil)
      end

      it 'where to fetch an accessible vm' do
        svc_vm = MiqAeMethodService::MiqAeServiceVmOrTemplate.where("name = ?", vm11.name).first
        expect(svc_vm.id).to eq(vm11.id)
      end

      it 'filter_objects on nil' do
        expect(MiqAeMethodService::MiqAeServiceVmOrTemplate.filter_objects(nil)).to eq(nil)
      end

      it 'filter_objects on empty array' do
        expect(MiqAeMethodService::MiqAeServiceVmOrTemplate.filter_objects([])).to eq([])
      end

      it 'find unaccessible objects' do
        expect(MiqAeMethodService::MiqAeServiceVmOrTemplate.find(vm21.id)).to eq(nil)
      end

      after do
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end
    end

    context "automate methods - enable rbac" do
      def collect_ids_with_rbac
        <<-'RUBY'
          $evm.enable_rbac
          $evm.root['vm_ids'] = $evm.vmdb('vm').all.collect(&:id)
        RUBY
      end

      it 'filter all vms for a user via method with rbac' do
        vm12
        vm13
        vm22
        create_ae_model_with_method(:name => 'FLINTSTONE', :ae_namespace => 'FRED',
                                    :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                    :method_name => 'OBELIX',
                                    :method_script => collect_ids_with_rbac)
        ws = MiqAeEngine.instantiate("/FRED/WILMA/DOGMATIX", user2)
        ids = [vm21.id, vm22.id]
        expect(ws.root("vm_ids")).to match_array(ids)
      end

      after do
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end
    end

    context "disable rbac" do
      before do
        @workspace = double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options)
        @workspace_class =  class_double("MiqAeEngine::MiqAeWorkspaceRuntime")
        @front  =  MiqAeMethodService::MiqAeServiceFront.new(@workspace)
        allow(@workspace).to receive(:rbac_enabled?).and_return(false)
        allow(@workspace).to receive(:rbac=)
        allow(@workspace_class).to receive(:current).and_return(@workspace)
        allow(DRb).to receive(:front).and_return(@front)
        allow(@workspace).to receive(:ae_user).and_return(user1)
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end

      it 'get count of vms per tenant' do
        vm12
        vm13
        vm22
        vm23
        count = MiqAeMethodService::MiqAeServiceVmOrTemplate.count
        expect(count).to eq(6)
      end

      it 'get all vms per tenant' do
        vm12
        vm13
        vm22
        vm23
        all_vms = MiqAeMethodService::MiqAeServiceVmOrTemplate.all
        ids = [vm11.id, vm12.id, vm13.id, vm21.id, vm22.id, vm23.id]
        expect(all_vms.collect(&:id)).to match_array(ids)
      end

      after do
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end
    end

    context "disable rbac - automate method" do
      def collect_ids_without_rbac
        <<-'RUBY'
          # RBAC is disabled by default
          # $evm.disable_rbac
          $evm.root['vm_ids'] = $evm.vmdb('vm').all.collect(&:id)
        RUBY
      end

      it 'filter all vms for a user via method without rbac' do
        vm12
        vm13
        vm22
        create_ae_model_with_method(:name => 'FLINTSTONE', :ae_namespace => 'FRED',
                                    :ae_class => 'WILMA', :instance_name => 'DOGMATIX',
                                    :method_name => 'OBELIX',
                                    :method_script => collect_ids_without_rbac)
        ws = MiqAeEngine.instantiate("/FRED/WILMA/DOGMATIX", user2)
        ids = [vm11.id, vm21.id, vm22.id, vm12.id, vm13.id]
        expect(ws.root("vm_ids")).to match_array(ids)
      end

      after do
        MiqAeEngine::MiqAeWorkspaceRuntime.current = nil
      end
    end
  end
end
