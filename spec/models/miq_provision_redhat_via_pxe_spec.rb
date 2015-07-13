require "spec_helper"

describe MiqProvisionRedhatViaPxe do
  context "A new provision request," do
    before(:each) do
      @os = OperatingSystem.new(:product_name => 'Microsoft Windows')
      User.any_instance.stub(:role).and_return("admin")
      @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver    = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
      UiTaskSet.stub(:find_by_name).and_return(@approver)
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
        @pr          = FactoryGirl.create(:miq_provision_request, :userid => @user.userid, :src_vm_id => @vm_template.id)
        @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
        @vm_prov = FactoryGirl.create(:miq_provision_redhat_via_pxe, :userid => @user.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
      end

      context "#prepare_for_clone_task" do
        before do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ems_ref => "test_ref")
          @vm_prov.stub(:dest_cluster).and_return(@ems_cluster)
        end

        it "with default options" do
          clone_options = @vm_prov.prepare_for_clone_task
          clone_options[:clone_type].should == :skeletal
        end

        it "with linked-clone true" do
          @vm_prov.options[:linked_clone] = true
          clone_options = @vm_prov.prepare_for_clone_task
          clone_options[:clone_type].should == :skeletal
        end

        it "with linked-clone false" do
          @vm_prov.options[:linked_clone] = false
          clone_options = @vm_prov.prepare_for_clone_task
          clone_options[:clone_type].should == :skeletal
        end
      end

      context "#provision_completed" do
        before do
          @vm_prov.destination = @vm
        end

        it "when phase is poll_destination_powered_off_in_vmdb" do
          @vm_prov.phase = "poll_destination_powered_off_in_vmdb"

          @vm.should_receive(:stop)
          @vm_prov.provision_completed

          @vm_prov.phase.should == "poll_destination_powered_off_in_vmdb"
        end

        it "when phase is not poll_destination_powered_off_in_vmdb" do
          @vm_prov.phase = "post_provision"

          @vm.should_not_receive(:stop)
          @vm_prov.provision_completed

          @vm_prov.phase.should == "post_provision"
        end
      end
    end
  end
end
