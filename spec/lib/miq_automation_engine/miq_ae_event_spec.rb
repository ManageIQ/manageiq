module MiqAeEventSpec
  describe MiqAeEvent do
    let(:tenant)   { FactoryGirl.create(:tenant) }
    let(:group)    { FactoryGirl.create(:miq_group, :tenant => tenant) }
    # admin user is needed to process Events
    let(:admin)    { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:user)     { FactoryGirl.create(:user_with_group, :userid => "test", :miq_groups => [group]) }
    let(:ems)      { FactoryGirl.create(:ext_management_system, :tenant => tenant) }

    describe ".raise_ems_event" do
      context "with VM event" do
        let(:vm_group) { group }
        let(:vm_owner) { nil }
        let(:vm) do
          FactoryGirl.create(:vm_vmware,
                             :ext_management_system => ems,
                             :miq_group             => vm_group,
                             :evm_owner             => vm_owner
                            )
        end
        let(:event) do
          FactoryGirl.create(:ems_event,
                             :event_type        => "CreateVM_Task_Complete",
                             :source            => "VC",
                             :ems_id            => ems.id,
                             :vm_or_template_id => vm.id
                            )
        end
        before { allow(MiqServer).to receive_messages(:my_zone => "zone test") }

        context "with user owned VM" do
          let(:vm_owner) { user }

          it "has tenant" do
            args = {:miq_group_id => group.id, :tenant_id => tenant.id, :user_id => user.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_ems_event(event)
          end
        end

        context "with group owned VM" do
          let(:vm_group) { FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant)) }

          it "has tenant" do
            args = {:user_id => admin.id, :miq_group_id => vm_group.id, :tenant_id => vm_group.tenant.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_ems_event(event)
          end
        end
      end
    end

    describe ".raise_evm_event" do
      context "with VM event" do
        let(:vm_group) { group }
        let(:vm_owner) { nil }
        let(:vm) do
          FactoryGirl.create(:vm_vmware,
                             :ext_management_system => ems,
                             :miq_group             => vm_group,
                             :evm_owner             => vm_owner
                            )
        end

        context "with user owned VM" do
          let(:vm_owner) { user }

          it "has tenant" do
            args = {:miq_group_id => group.id, :tenant_id => tenant.id, :user_id => user.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_evm_event("vm_create", vm, :vm => vm)
          end
        end

        context "with group owned VM" do
          let(:vm_group) { FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant)) }

          it "has tenant" do
            args = {:user_id => admin.id, :miq_group_id => vm_group.id, :tenant_id => vm_group.tenant.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_evm_event("vm_create", vm, :vm => vm)
          end
        end
      end

      context "with Host event" do
        it "has tenant from provider" do
          host = FactoryGirl.create(:host, :ext_management_system => ems)
          args = {
            :user_id      => admin.id,
            :miq_group_id => ems.tenant.default_miq_group.id,
            :tenant_id    => ems.tenant.id
          }
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

          MiqAeEvent.raise_evm_event("host_provisioned", host, :host => host)
        end

        it "without a provider, has tenant from root tenant" do
          host = FactoryGirl.create(:host)

          args = {
            :user_id      => admin.id,
            :miq_group_id => Tenant.root_tenant.default_miq_group.id,
            :tenant_id    => Tenant.root_tenant.id
          }
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

          MiqAeEvent.raise_evm_event("host_provisioned", host, :host => host)
        end
      end

      context "with MiqServer event" do
        it "has tenant" do
          miq_server = EvmSpecHelper.local_miq_server(:is_master => true)
          worker = FactoryGirl.create(:miq_worker, :miq_server_id => miq_server.id)
          args   = {:user_id      => admin.id,
                    :miq_group_id => admin.current_group.id,
                    :tenant_id    => admin.current_group.current_tenant.id
          }
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

          MiqAeEvent.raise_evm_event("evm_worker_start", worker.miq_server)
        end
      end

      context "with Storage event" do
        it "has tenant" do
          storage = FactoryGirl.create(:storage, :name => "test_storage_vmfs", :store_type => "VMFS")
          FactoryGirl.create(:host, :name => "test_host", :hostname => "test_host", :state => 'on', :ems_id => ems.id, :storages => [storage])
          args = {:user_id      => admin.id,
                  :miq_group_id => ems.tenant.default_miq_group.id,
                  :tenant_id    => ems.tenant.id
          }
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

          MiqAeEvent.raise_evm_event("request_storage_scan", storage)
        end
      end

      context "with MiqRequest event" do
        it "has tenant" do
          request = FactoryGirl.create(:vm_reconfigure_request, :requester => user)
          args    = {:user_id      => user.id,
                     :miq_group_id => user.current_group.id,
                     :tenant_id    => user.current_tenant.id
          }
          expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

          MiqAeEvent.raise_evm_event("request_approved", request)
        end
      end

      context "with Service event" do
        let(:service_group) { group }
        let(:service_owner) { nil }
        let(:service)       { FactoryGirl.create(:service, :miq_group => service_group, :evm_owner => service_owner) }

        context "with user owned service" do
          let(:service_owner) { user }

          it "has tenant" do
            args = {:miq_group_id => group.id, :tenant_id => tenant.id, :user_id => user.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_evm_event("service_started", service)
          end
        end

        context "with group owned service" do
          let(:service_group) { FactoryGirl.create(:miq_group, :tenant => FactoryGirl.create(:tenant)) }

          it "has tenant" do
            args = {:user_id => admin.id, :miq_group_id => service_group.id, :tenant_id => service_group.tenant.id}
            expect(MiqAeEngine).to receive(:deliver_queue).with(hash_including(args), anything)

            MiqAeEvent.raise_evm_event("service_started", service)
          end
        end
      end
    end
  end
end
