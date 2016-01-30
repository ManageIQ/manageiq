describe ManageIQ::Providers::Redhat::InfraManager::ProvisionViaPxe do
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
        :provision_type => "pxe"
      }
    end

    context "RHEV-M provisioning" do
      before(:each) do
        @ems         = FactoryGirl.create(:ems_redhat_with_authentication)
        @vm_template = FactoryGirl.create(:template_redhat, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryGirl.create(:vm_redhat, :name => "vm1",       :location => "abc/def.vmx")
        @pr          = FactoryGirl.create(:miq_provision_request, :requester => @admin, :src_vm_id => @vm_template.id)
        @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
        @vm_prov = FactoryGirl.create(:miq_provision_redhat_via_pxe, :userid => @admin.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
      end

      context "#prepare_for_clone_task" do
        before do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ems_ref => "test_ref")
          allow(@vm_prov).to receive(:dest_cluster).and_return(@ems_cluster)
        end

        it "with default options" do
          clone_options = @vm_prov.prepare_for_clone_task
          expect(clone_options[:clone_type]).to eq(:skeletal)
        end

        it "with linked-clone true" do
          @vm_prov.options[:linked_clone] = true
          clone_options = @vm_prov.prepare_for_clone_task
          expect(clone_options[:clone_type]).to eq(:skeletal)
        end

        it "with linked-clone false" do
          @vm_prov.options[:linked_clone] = false
          clone_options = @vm_prov.prepare_for_clone_task
          expect(clone_options[:clone_type]).to eq(:skeletal)
        end
      end

      context "#provision_completed" do
        before do
          @vm_prov.destination = @vm
        end

        it "when phase is poll_destination_powered_off_in_vmdb" do
          @vm_prov.phase = "poll_destination_powered_off_in_vmdb"

          expect(@vm).to receive(:stop)
          @vm_prov.provision_completed

          expect(@vm_prov.phase).to eq("poll_destination_powered_off_in_vmdb")
        end

        it "when phase is not poll_destination_powered_off_in_vmdb" do
          @vm_prov.phase = "post_provision"

          expect(@vm).not_to receive(:stop)
          @vm_prov.provision_completed

          expect(@vm_prov.phase).to eq("post_provision")
        end
      end
    end
  end
end
