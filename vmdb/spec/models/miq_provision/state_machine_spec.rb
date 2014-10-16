require "spec_helper"

describe MiqProvision do
  context "::StateMachine" do
    context "#prepare_provision" do
      let(:ems)      { FactoryGirl.create(:ems_openstack_with_authentication) }
      let(:flavor)   { FactoryGirl.create(:flavor_openstack, :ext_management_system => ems) }
      let(:template) { FactoryGirl.create(:template_openstack, :ext_management_system => ems) }
      let(:options)  { {:src_vm_id => template.id, :vm_target_name => "test_vm_1"} }
      let(:task)     { FactoryGirl.create(:miq_provision_openstack, :source => template, :state => 'pending', :status => 'Ok', :options => options ) }
      it "merges :clone_options from automate" do
        task.stub(:update_and_notify_parent)
        task.should_receive(:instance_type).and_return(flavor)
        task.should_receive(:signal).with(:start_clone_task)

        task.prepare_provision
      end
    end

    context "#post_create_destination" do
      before(:each) do
        @ems      = FactoryGirl.create(:ems_vmware_with_authentication)
        @template = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
        @vm       = FactoryGirl.create(:vm_vmware)
        @options  = {:src_vm_id => @template.id}

        @task = FactoryGirl.create(:miq_provision, :source => @template, :destination => @vm, :state => 'pending', :status => 'Ok', :options => @options )
        @task.stub(:miq_request => double("MiqRequest").as_null_object)

        @task.should_receive(:mark_as_completed)
      end

      it "sets description" do
        description = "foo bar"
        @options[:vm_description] = description
        @task.update_attributes(:options => @options)

        @task.signal(:post_create_destination)

        @task.destination.description.should == description
        @vm.reload.description.should        == description
      end

      it "sets ownership" do
        user = FactoryGirl.create(:user, :email => "foo@example.com")
        @options[:owner_email] = user.email
        @task.update_attributes(:options => @options)

        @task.signal(:post_create_destination)

        @task.destination.evm_owner.should == user
        @vm.reload.evm_owner.should        == user
      end

      context "sets retirement" do
        it "with :retirement option" do
          retirement = 2.days.to_i
          retires_on = (Time.now.utc + retirement).to_date
          @options[:retirement] = retirement
          @task.update_attributes(:options => @options)

          @task.signal(:post_create_destination)

          @task.destination.retires_on.should == retires_on
          @vm.reload.retires_on.should        == retires_on

          @vm.retired.should be_false
          @vm.retirement_warn.should == 0
        end

        it "with :retirement_time option" do
          retirement_warn_days    = 7
          retirement_warn_seconds = retirement_warn_days.days.to_i
          @options[:retirement_warn] = retirement_warn_seconds

          retirement_time = Time.now.utc + 3.days
          retires_on = retirement_time.to_date
          @options[:retirement] = 2.days.to_i
          @options[:retirement_time] = retirement_time  # This setting overrides the :retirement setting

          @task.update_attributes(:options => @options)

          @task.signal(:post_create_destination)

          @task.destination.retires_on.should == retires_on
          @vm.reload.retires_on.should        == retires_on

          @vm.retired.should be_false
          @vm.retirement_warn.should == retirement_warn_days
        end
      end

      it "sets genealogy" do
        @task.signal(:post_create_destination)

        @task.destination.with_relationship_type("genealogy") { |v| v.parent.should == @template }
        @vm.reload.with_relationship_type("genealogy")        { |v| v.parent.should == @template }
        @template.reload.with_relationship_type("genealogy")  { |v| v.children.should == [@vm] }
      end
    end
  end
end
