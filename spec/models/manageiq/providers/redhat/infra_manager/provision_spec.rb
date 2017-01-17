describe ManageIQ::Providers::Redhat::InfraManager::Provision do
  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      @admin = FactoryGirl.create(:user_admin)
      @target_vm_name = 'clone test'
      @options = {
        :pass           => 1,
        :vm_name        => @target_vm_name,
        :vm_target_name => @target_vm_name,
        :number_of_vms  => 1,
        :cpu_limit      => -1,
        :cpu_reserve    => 0,
        :provision_type => "rhevm",
        :disks_add      => {}
      }
    end

    context "RHEV-M provisioning" do
      before(:each) do
        @ems         = FactoryGirl.create(:ems_redhat_with_authentication)
        @vm_template = FactoryGirl.create(:template_redhat, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryGirl.create(:vm_redhat, :name => "vm1",       :location => "abc/def.vmx")
        @pr          = FactoryGirl.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
        @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
        @vm_prov = FactoryGirl.create(:miq_provision_redhat, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
      end

      it "#workflow" do
        workflow_class = ManageIQ::Providers::Redhat::InfraManager::ProvisionWorkflow
        allow_any_instance_of(workflow_class).to receive(:get_dialogs).and_return(:dialogs => {})

        expect(@vm_prov.workflow.class).to eq workflow_class
        expect(@vm_prov.workflow_class).to eq workflow_class
      end

      it "eligible_resources for iso_images" do
        iso_image = FactoryGirl.create(:iso_image, :name => "Test ISO Image")
        iso_image_struct = [MiqHashStruct.new(:id => "IsoImage::#{iso_image.id}", :name => iso_image.name, :evm_object_class => iso_image.class.base_class.name.to_sym)]
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_iso_images).and_return(iso_image_struct)
        expect(@vm_prov.eligible_resources(:iso_images)).to eq([iso_image])
      end

      context "#sparse_disk_value" do
        it "with nil disk_format value" do
          expect(@vm_prov.sparse_disk_value).to be_nil
        end

        it "with :default disk_format value" do
          @vm_prov.options[:disk_format] = %w(default Default)
          expect(@vm_prov.sparse_disk_value).to be_nil
        end

        it "with :thin disk_format value" do
          @vm_prov.options[:disk_format] = %w(thin Thin)
          expect(@vm_prov.sparse_disk_value).to be_truthy
        end

        it "with :preallocated disk_format value" do
          @vm_prov.options[:disk_format] = %w(preallocated Preallocated)
          expect(@vm_prov.sparse_disk_value).to be_falsey
        end
      end

      context "#prepare_for_clone_task" do
        before do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ems_ref => "test_ref")
          allow(@vm_prov).to receive(:dest_cluster).and_return(@ems_cluster)
        end

        it "with default options" do
          clone_options = @vm_prov.prepare_for_clone_task

          expect(clone_options[:name]).to eq(@target_vm_name)
          expect(clone_options[:clone_type]).to eq(:full)
          expect(clone_options[:cluster]).to eq(@ems_cluster.ems_ref)
        end

        it "with linked-clone true" do
          @vm_prov.options[:linked_clone] = true
          clone_options = @vm_prov.prepare_for_clone_task

          expect(clone_options[:clone_type]).to eq(:linked)
        end

        it "with linked-clone false" do
          @vm_prov.options[:linked_clone] = false
          clone_options = @vm_prov.prepare_for_clone_task

          expect(clone_options[:clone_type]).to eq(:full)
        end
      end

      context "#log_clone_options" do
        let(:ems_cluster) { FactoryGirl.create(:ems_cluster, :ems_ref => "test_ref") }
        before do
          allow(@vm_prov).to receive(:dest_cluster).and_return(ems_cluster)
        end

        it "doesnt display passwords for clone options" do
          # dest_cluster
          @vm_prov.options[:root_password] = "HIDDEN_PASSWORD"
          clone_options = @vm_prov.prepare_for_clone_task

          expect($log).not_to receive(:info).with(/HIDDEN_PASSWORD/)
          @vm_prov.log_clone_options(clone_options)
        end
      end

      context "with a destination vm" do
        before do
          rhevm_vm = double(:attributes => {:status => {:state => "down"}})
          allow(@vm_prov).to receive(:get_provider_destination).and_return(rhevm_vm)
        end

        context "destination_image_locked?" do
          it "with a powered-off destination" do
            expect(subject.destination_image_locked?).to be_falsey
          end

          it "with an imaged_locked destination" do
            @vm_prov.get_provider_destination.attributes[:status][:state] = "image_locked"

            expect(@vm_prov.destination_image_locked?).to be_truthy
          end

          it "when destination is nil" do
            allow(@vm_prov).to receive(:get_provider_destination).and_return(nil)
            expect(@vm_prov.destination_image_locked?).to be_falsey
          end
        end

        context "customize_destination" do
          it "when destination_image_locked is false" do
            allow(@vm_prov).to receive(:for_destination).and_return("display_string")
            expect(@vm_prov).to receive(:configure_container)

            @vm_prov.customize_destination
          end

          it "when destination_image_locked is true" do
            @vm_prov.get_provider_destination.attributes[:status][:state] = "image_locked"
            expect(@vm_prov).to receive(:requeue_phase)

            @vm_prov.customize_destination
          end
        end

        context "configure_disks" do
          before do
            allow(@vm_prov).to receive(:for_destination).and_return("display_string")
            allow(@vm_prov).to receive(:configure_container)
          end

          it "when adding disks is required" do
            allow(@vm_prov).to receive(:configure_dialog_disks)
            allow(@vm_prov).to receive(:add_disks)
            expect(@vm_prov).to receive(:poll_add_disks_complete)

            @vm_prov.customize_destination
          end

          it "when adding disks is not required" do
            expect(@vm_prov).to receive(:configure_disks)
            expect(@vm_prov).not_to receive(:poll_add_disks_complete)

            @vm_prov.customize_destination
          end
        end
      end
    end
  end
end
