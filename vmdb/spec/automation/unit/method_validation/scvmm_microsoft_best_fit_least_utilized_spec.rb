require "spec_helper"

describe "SCVMM microsoft_best_fit_least_utilized" do
  let(:ws) do
    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Infrastructure/VM/Provisioning&class=Placement" \
                            "&instance=default&message=microsoft&" \
                            "MiqProvision::miq_provision=#{miq_provision.id}")
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
                       :state   => 'active',
                       :status  => 'Ok')
  end

  let(:host)    { FactoryGirl.create(:host_microsoft, :power_state => "on") }
  let(:storage) { FactoryGirl.create(:storage) }

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
        MiqProvisionMicrosoftWorkflow.any_instance.stub(:allowed_hosts).and_return([host_struct])
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
          MiqProvisionMicrosoftWorkflow.any_instance.stub(:allowed_storages).and_return([storage_struct])
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
    end
  end
end
