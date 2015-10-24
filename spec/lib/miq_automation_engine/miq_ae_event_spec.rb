require 'spec_helper'

module MiqAeEventSpec
  describe MiqAeEvent do
    before do
      @tenant = FactoryGirl.create(:tenant)
      @group  = FactoryGirl.create(:miq_group, :tenant => @tenant)
      # admin user is needed to process Events
      @admin  = FactoryGirl.create(:user_with_group, :userid => "admin")
      @user   = FactoryGirl.create(:user_with_group, :userid => "test", :miq_groups => [@group])
      @ems    = FactoryGirl.create(:ext_management_system, :tenant => @tenant)
      @vm     = FactoryGirl.create(:vm_vmware, :ext_management_system => @ems, :miq_group => @group)
      MiqServer.stub(:my_zone => "zone 1")
    end

    context ".raise_ems_event" do
      before do
        @event  = FactoryGirl.create(:ems_event,
                                     :event_type        => "CreateVM_Task_Complete",
                                     :source            => "VC",
                                     :ems_id            => @ems.id,
                                     :vm_or_template_id => @vm.id
                                    )

        @args = {:miq_group_id => @group.id, :tenant_id => @tenant.id}
      end

      it "VM with user owner" do
        @vm.update_attributes(:evm_owner => @user)
        @args.merge!(:user_id => @user.id)
        expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(@args), anything)

        MiqAeEvent.raise_ems_event(@event)
      end

      it "VM with group owner" do
        miq_group = FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant))
        @vm.update_attributes(:miq_group => miq_group)
        @args.merge!(:user_id => @admin.id, :miq_group_id => miq_group.id, :tenant_id => miq_group.tenant.id)
        expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(@args), anything)

        MiqAeEvent.raise_ems_event(@event)
      end
    end

    context ".raise_evm_event" do
      context "VM" do
        before do
          @event = "vm_create"
          @args  = {:miq_group_id => @group.id, :tenant_id => @tenant.id}
        end

        it "with user owner" do
          @vm.update_attributes(:evm_owner => @user)
          @args.merge!(:user_id => @user.id)
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(@args), anything)

          MiqAeEvent.raise_evm_event(@event, @vm, :vm => @vm)
        end

        it "with group owner" do
          miq_group = FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant))
          @vm.update_attributes(:miq_group => miq_group)
          @args.merge!(:user_id => @admin.id, :miq_group_id => miq_group.id, :tenant_id => miq_group.tenant.id)
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(@args), anything)

          MiqAeEvent.raise_evm_event(@event, @vm, :vm => @vm)
        end
      end

      it "Host" do
        # Remove this when miq_group is added to ems
        @ems.stub(:miq_group => @group)
        host  = FactoryGirl.create(:host, :ext_management_system => @ems)
        event = "host_provisioned"
        args  = {:miq_group_id => @group.id, :tenant_id => @group.tenant.id}
        expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

        MiqAeEvent.raise_evm_event(event, host, :host => host)
      end

      it "MiqServer" do
        miq_server = EvmSpecHelper.local_miq_server(:is_master => true)
        worker = FactoryGirl.create(:miq_worker, :miq_server_id => miq_server.id)
        event  = "evm_worker_start"
        args   = {:user_id      => @admin.id,
                  :miq_group_id => @admin.current_group.id,
                  :tenant_id    => @admin.current_group.current_tenant.id
        }
        expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

        MiqAeEvent.raise_evm_event(event, worker.miq_server)
      end
    end
  end
end
