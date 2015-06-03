require "spec_helper"

describe MiqProvisionRedhat do
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
        :provision_type => "rhevm"
      }
    end

    context "RHEV-M provisioning" do
      before(:each) do
        @ems         = FactoryGirl.create(:ems_redhat_with_authentication)
        @vm_template = FactoryGirl.create(:template_redhat, :name => "template1", :ext_management_system => @ems, :operating_system => @os, :cpu_limit => -1, :cpu_reserve => 0)
        @vm          = FactoryGirl.create(:vm_redhat, :name => "vm1",       :location => "abc/def.vmx")
        @pr          = FactoryGirl.create(:miq_provision_request, :userid => @user.userid, :src_vm_id => @vm_template.id)
        @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
        @vm_prov = FactoryGirl.create(:miq_provision_redhat, :userid => @user.userid, :miq_request => @pr, :source => @vm_template, :request_type => 'template', :state => 'pending', :status => 'Ok', :options => @options)
      end

      it "#workflow" do
        MiqProvisionWorkflow.any_instance.stub(:get_dialogs).and_return(:dialogs => {})

        @vm_prov.workflow.class.should eq MiqProvisionRedhatWorkflow
      end

      it "disable_customization_spec" do
        @vm_prov.should_receive(:disable_customization_spec).never
        @vm_prov.set_customization_spec(nil).should be_false
      end

      it "eligible_resources for iso_images" do
        iso_image = FactoryGirl.create(:iso_image, :name => "Test ISO Image")
        iso_image_struct = [MiqHashStruct.new(:id => "IsoImage::#{iso_image.id}", :name => iso_image.name, :evm_object_class => iso_image.class.base_class.name.to_sym)]
        MiqProvisionWorkflow.any_instance.stub(:allowed_iso_images).and_return(iso_image_struct)
        @vm_prov.eligible_resources(:iso_images).should == [iso_image]
      end

      context "#sparse_disk_value" do
        it "with nil disk_format value" do
          @vm_prov.sparse_disk_value.should be_nil
        end

        it "with :default disk_format value" do
          @vm_prov.options[:disk_format] = %w(default Default)
          @vm_prov.sparse_disk_value.should be_nil
        end

        it "with :thin disk_format value" do
          @vm_prov.options[:disk_format] = %w(thin Thin)
          @vm_prov.sparse_disk_value.should be_true
        end

        it "with :preallocated disk_format value" do
          @vm_prov.options[:disk_format] = %w(preallocated Preallocated)
          @vm_prov.sparse_disk_value.should be_false
        end
      end

      context "#prepare_for_clone_task" do
        before do
          @ems_cluster = FactoryGirl.create(:ems_cluster, :ems_ref => "test_ref")
          @vm_prov.stub(:dest_cluster).and_return(@ems_cluster)
        end

        it "with default options" do
          clone_options = @vm_prov.prepare_for_clone_task

          clone_options[:name].should       == @target_vm_name
          clone_options[:clone_type].should == :full
          clone_options[:cluster].should    == @ems_cluster.ems_ref
        end

        it "with linked-clone true" do
          @vm_prov.options[:linked_clone] = true
          clone_options = @vm_prov.prepare_for_clone_task

          clone_options[:clone_type].should == :linked
        end

        it "with linked-clone false" do
          @vm_prov.options[:linked_clone] = false
          clone_options = @vm_prov.prepare_for_clone_task

          clone_options[:clone_type].should == :full
        end
      end

      context "with a destination vm" do
        before do
          rhevm_vm = double(:attributes => {:status => {:state => "down"}})
          @vm_prov.stub(:get_provider_destination).and_return(rhevm_vm)
        end

        context "destination_image_locked?" do
          it "with a powered-off destination" do
            subject.destination_image_locked?.should be_false
          end

          it "with an imaged_locked destination" do
            @vm_prov.get_provider_destination.attributes[:status][:state] = "image_locked"

            @vm_prov.destination_image_locked?.should be_true
          end

          it "when destination is nil" do
            @vm_prov.stub(:get_provider_destination).and_return(nil)
            @vm_prov.destination_image_locked?.should be_false
          end
        end

        context "customize_destination" do
          it "when destination_image_locked is false" do
            @vm_prov.stub(:for_destination).and_return("display_string")
            @vm_prov.should_receive(:configure_container)

            @vm_prov.customize_destination
          end

          it "when destination_image_locked is true" do
            @vm_prov.get_provider_destination.attributes[:status][:state] = "image_locked"
            @vm_prov.should_receive(:requeue_phase)

            @vm_prov.customize_destination
          end
        end
      end
    end
  end
end
