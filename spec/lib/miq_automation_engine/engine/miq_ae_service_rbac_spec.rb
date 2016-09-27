module MiqAeServiceModelSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceVmOrTemplate do
    include Spec::Support::AutomationHelper
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
