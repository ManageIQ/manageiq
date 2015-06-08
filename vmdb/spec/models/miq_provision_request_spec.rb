require "spec_helper"

describe MiqProvisionRequest do
  it ".request_task_class_from" do
    vm = FactoryGirl.create(:vm_vmware)
    described_class.request_task_class_from('options' => {:src_vm_id => vm.id}).should == MiqProvisionVmware

    vm = FactoryGirl.create(:vm_redhat)
    described_class.request_task_class_from('options' => {:src_vm_id => vm.id}).should == MiqProvisionRedhat
  end

  context "A new provision request," do
    before            { User.any_instance.stub(:role).and_return("admin") }
    let(:approver)    { FactoryGirl.create(:user_miq_request_approver) }
    let(:user)        { FactoryGirl.create(:user) }
    let(:vm)          { FactoryGirl.create(:vm_vmware, :name => "vm1", :location => "abc/def.vmx") }
    let(:vm_template) { FactoryGirl.create(:template_vmware, :name => "template1") }

    it "should not be created without userid being specified" do
      lambda { FactoryGirl.create(:miq_provision_request) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with an invalid userid being specified" do
      lambda { FactoryGirl.create(:miq_provision_request, :userid => 'barney', :src_vm_id => vm_template.id ) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with a valid userid but no vm being specified" do
      lambda { FactoryGirl.create(:miq_provision_request, :userid => user.userid) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should be created from either a VM or Template" do
      lambda { FactoryGirl.create(:miq_provision_request, :userid => user.userid, :src_vm_id => vm_template.id) }.should_not raise_error
      lambda { FactoryGirl.create(:miq_provision_request, :userid => user.userid, :src_vm_id => vm.id) }.should_not raise_error
    end

    it "should not be created with a valid userid but invalid vm being specified" do
      lambda { FactoryGirl.create(:miq_provision_request, :userid => user.userid, :src_vm_id => 42) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    context "with a valid userid and source vm," do
      before do
        @pr = FactoryGirl.create(:miq_provision_request, :userid => user.userid, :src_vm_id => vm_template.id, :options => {:owner_email => 'tester@miq.com'})
        @pr.create_request
        @request = @pr.miq_request
      end

      it "should create an MiqProvisionRequest" do
        MiqProvisionRequest.count.should == 1
        MiqProvisionRequest.first.should == @pr
        @pr.valid?.should be_true
        @pr.approved?.should be_false
      end

      it "should create a valid MiqRequest" do
        @pr.miq_request.should == MiqRequest.first
        @pr.miq_request.valid?.should be_true
        @pr.miq_request.approval_state.should == "pending_approval"
        @pr.miq_request.resource.should == @pr
        @pr.miq_request.requester_userid.should == user.userid
        @pr.miq_request.stamped_on.should be_nil

        @pr.miq_request.approved?.should be_false
        MiqApproval.count.should == 1
        @pr.miq_request.first_approval.should == MiqApproval.first
      end

      it "should return a workflow class" do
        @pr.workflow_class.should == MiqProvisionVmwareWorkflow
      end

      context "when calling call_automate_event_queue" do
        before do
          MiqServer.stub(:my_zone).and_return("default")
          @event_name = "request_created"
          @pr.miq_request.call_automate_event_queue(@event_name)
        end

        it "should create proper MiqQueue item" do
          MiqQueue.count.should == 1
          q = MiqQueue.first
          q.class_name.should  == @pr.miq_request.class.name
          q.instance_id.should == @pr.miq_request.id
          q.method_name.should == "call_automate_event"
          q.args.should        == [@event_name]
          q.zone.should        == "default"
        end
      end

      context "after MiqRequest is deleted," do
        before { @request.destroy }

        it "should delete MiqProvisionRequest" do
          MiqProvisionRequest.count.should == 0
        end

        it "should delete MiqApproval" do
          MiqApproval.count.should == 0
        end

        it "should not delete Approver" do
          lambda { approver.reload }.should_not raise_error
        end
      end

      context "when calling quota methods" do
        before { EvmSpecHelper.create_guid_miq_server_zone }

        it "should return a hash for quota methods" do
          [:vms_by_group, :vms_by_owner, :retired_vms_by_group, :retired_vms_by_owner, :provisions_by_group, :provisions_by_owner,
           :requests_by_group, :requests_by_owner, :active_provisions_by_group, :active_provisions_by_owner, :active_provisions].each do |quota_method|
            @pr.check_quota(quota_method).should be_kind_of(Hash)
          end
        end

        it "should return stats from quota methods" do
          prov_options = {:number_of_vms => [2, '2'], :owner_email => 'tester@miq.com', :vm_memory => ['1024','1024'], :number_of_cpus => [2, '2']}
          @pr2 = FactoryGirl.create(:miq_provision_request, :userid => user.userid, :src_vm_id => vm_template.id, :options => prov_options)
          @pr2.create_request

          #:requests_by_group
          stats = @pr.check_quota(:requests_by_owner)
          stats.should be_kind_of(Hash)

          stats[:class_name].should == "MiqProvisionRequest"
          stats[:count].should == 2
          stats[:memory].should == 2048
          stats[:cpu].should == 4
          stats.fetch_path(:active, :class_name).should == "MiqProvision"
        end
      end

      context "when processing tags" do
        before { FactoryGirl.create(:classification_department_with_tags) }

        it "should add and delete tags from a request" do
          @pr.get_tags.length.should == 0

          t = Classification.find(:first, :conditions => {:description => 'Department', :parent_id => 0}, :include => :tag)
          @pr.add_tag(t.name, t.children.first.name)
          @pr.get_tags[t.name.to_sym].should be_kind_of(String) # Single tag returns as a String
          @pr.get_tags[t.name.to_sym].should == t.children.first.name

          # Adding the same tag again should not increase the tag count
          @pr.add_tag(t.name, t.children.first.name)
          @pr.get_tags[t.name.to_sym].should be_kind_of(String) # Single tag returns as a String
          @pr.get_tags[t.name.to_sym].should == t.children.first.name

          # Verify that #get_tag with classification returns the single child tag name
          @pr.get_tags[t.name.to_sym].should == @pr.get_tag(t.name)

          t.children.each { |c| @pr.add_tag(t.name, c.name) }
          @pr.get_tags[t.name.to_sym].should be_kind_of(Array)
          @pr.get_tags[t.name.to_sym].length.should == t.children.length

          child_names = t.children.collect(&:name)
          # Make sure each child name is yield from the tag method
          @pr.tags { |tag_name, _classification| child_names.delete(tag_name) }
          child_names.should be_empty

          tags = @pr.get_classification(t.name)
          tags.should be_kind_of(Array)
          classification = tags.first
          classification.should be_kind_of(Hash)
          classification.keys.should include(:name)
          classification.keys.should include(:description)

          child_names = t.children.collect(&:name)

          @pr.clear_tag(t.name, child_names[0])
          @pr.get_tags[t.name.to_sym].should be_kind_of(Array) # Multiple tags return as an Array
          @pr.get_tags[t.name.to_sym].length.should == t.children.length - 1

          @pr.clear_tag(t.name, child_names[1])
          @pr.get_tags[t.name.to_sym].should be_kind_of(String) # Single tag returns as a String
          @pr.get_tags[t.name.to_sym].should == child_names[2]

          @pr.clear_tag(t.name)
          @pr.get_tags[t.name.to_sym].should be_nil # No tags returns as nil
          @pr.get_tags.length.should == 0
        end

        it "should return classifications for tags" do
          @pr.get_tags.length.should == 0

          t = Classification.find(:first, :conditions => {:description => 'Department', :parent_id => 0}, :include => :tag)
          @pr.add_tag(t.name, t.children.first.name)
          @pr.get_tags[t.name.to_sym].should be_kind_of(String)

          classification = @pr.get_classification(t.name)
          classification.should be_kind_of(Hash)
          classification.keys.should include(:name)
          classification.keys.should include(:description)

          @pr.add_tag(t.name, t.children[1].name)
          @pr.get_tags[t.name.to_sym].should be_kind_of(Array)

          classification = @pr.get_classification(t.name)
          classification.should be_kind_of(Array)
          first = classification.first
          first.keys.should include(:name)
          first.keys.should include(:description)
        end
      end
    end
  end
end
