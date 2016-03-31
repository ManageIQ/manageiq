describe "SCVMM microsoft_best_fit_least_utilized" do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Infrastructure/VM/Provisioning&class=Placement" \
                            "&instance=default&message=microsoft&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}", user)
  end
  let(:vm_template) do
    FactoryGirl.create(:template_microsoft,
                       :name                  => "template1",
                       :ext_management_system => FactoryGirl.create(:ems_microsoft_with_authentication))
  end
  let(:miq_provision) do
    FactoryGirl.create(:miq_provision_microsoft,
                       :options => {:src_vm_id      => vm_template.id,
                                    :placement_auto => [true, 1]},
                       :userid  => user.userid,
                       :state   => 'active',
                       :status  => 'Ok')
  end

  let(:host)       { FactoryGirl.create(:host_microsoft, :power_state => "on") }
  let(:storage)    { FactoryGirl.create(:storage, :free_space => 10.gigabytes) }
  let(:ro_storage) { FactoryGirl.create(:storage, :free_space => 20.gigabytes) }

  context "provision task object" do
    it "without host or storage will not set placement values" do
      ws.root
      miq_provision.reload

      expect(miq_provision.options[:placement_host_name]).to be_nil
      expect(miq_provision.options[:placement_ds_name]).to   be_nil
    end

    context "with an eligible host" do
      before do
        host_struct = MiqHashStruct.new(:id               => host.id,
                                        :evm_object_class => host.class.base_class.name.to_sym)
        allow_any_instance_of(ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow)
          .to receive(:allowed_hosts).and_return([host_struct])
      end

      it "without storage will not set placement values" do
        ws.root
        miq_provision.reload

        expect(miq_provision.options[:placement_host_name]).to be_nil
        expect(miq_provision.options[:placement_ds_name]).to   be_nil
      end

      context "with storage" do
        before do
          host.storages << storage
          storage_struct = MiqHashStruct.new(:id               => storage.id,
                                             :evm_object_class => storage.class.base_class.name.to_sym)
          allow_any_instance_of(ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow)
            .to receive(:allowed_storages).and_return([storage_struct])
        end

        it "will set placement values" do
          ws.root
          miq_provision.reload

          expect(miq_provision.options[:placement_host_name]).to eq([host.id, host.name])
          expect(miq_provision.options[:placement_ds_name]).to   eq([storage.id, storage.name])
        end

        it "will not set placement values when placement_auto is false" do
          miq_provision.update_attributes(:options => miq_provision.options.merge(:placement_auto => [false, 0]))
          ws.root
          miq_provision.reload

          expect(miq_provision.options[:placement_host_name]).to be_nil
          expect(miq_provision.options[:placement_ds_name]).to   be_nil
        end
      end

      context "with read-only storage" do
        before do
          host.storages << [ro_storage, storage]
          HostStorage.where(:host_id => host.id, :storage_id => ro_storage.id).update(:read_only => true)

          evm_object_class = storage.class.base_class.name.to_sym
          storage_struct = [MiqHashStruct.new(:id => ro_storage.id, :evm_object_class => evm_object_class),
                            MiqHashStruct.new(:id => storage.id,    :evm_object_class => evm_object_class)]
          allow_any_instance_of(ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow)
            .to receive(:allowed_storages).and_return(storage_struct)
        end

        it "picks the largest writable datastore" do
          ws.root
          miq_provision.reload

          expect(miq_provision.options[:placement_host_name]).to eq([host.id, host.name])
          expect(miq_provision.options[:placement_ds_name]).to   eq([storage.id, storage.name])
        end
      end
    end
  end
end
