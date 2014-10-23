require "spec_helper"

describe MiqHostProvisionRequest do
  context "A new provision request," do
    before(:each) do
      User.any_instance.stub(:role).and_return("admin")
      @user     = FactoryGirl.create(:user)
      @approver = FactoryGirl.create(:user_miq_request_approver)
    end

    it "should not be created without userid being specified" do
      lambda { FactoryGirl.create(:miq_host_provision_request) }.should raise_error(ActiveRecord::RecordInvalid)
    end

    it "should not be created with an invalid userid being specified" do
      lambda { FactoryGirl.create(:miq_host_provision_request, :userid => 'barney') }.should raise_error(ActiveRecord::RecordInvalid)
    end

    context "with a valid userid and host," do
      before(:each) do
        @pr        = FactoryGirl.create(:miq_host_provision_request, :userid => @user.userid)
        @pr.create_request
        @request   = @pr.miq_request
        @approvals = @request.miq_approvals
      end

      it "should create an MiqHostProvisionRequest" do
        MiqHostProvisionRequest.count.should == 1
        MiqHostProvisionRequest.first.should == @pr
        @pr.valid?.should be_true
        @pr.approved?.should be_false
      end

      it "should create a valid MiqRequest" do
        @pr.miq_request.should == MiqRequest.first
        @pr.miq_request.valid?.should be_true
        @pr.miq_request.approval_state.should == "pending_approval"
        @pr.miq_request.resource.should == @pr
        @pr.miq_request.requester_userid.should == @user.userid
        @pr.miq_request.stamped_on.should be_nil

        @pr.miq_request.approved?.should be_false
        MiqApproval.count.should == 1
        @pr.miq_request.first_approval.should == @approvals.first
      end

      it "should return a workflow class" do
          @pr.workflow_class.should == MiqHostProvisionWorkflow
      end

      context "when calling call_automate_event_queue" do
        before(:each) do
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
        before(:each) do
          @request.destroy
        end

        it "should delete MiqHostProvisionRequest" do
          MiqHostProvisionRequest.count.should == 0
        end

        it "should delete MiqApproval" do
          MiqApproval.count.should == 0
        end

        it "should not delete Approver" do
          lambda { @approver.reload }.should_not raise_error
        end
      end

      context "when processing tags" do
        before do
          FactoryGirl.create(:classification_department_with_tags)
        end

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

          t.children.each {|c| @pr.add_tag(t.name, c.name)}
          @pr.get_tags[t.name.to_sym].should be_kind_of(Array)
          @pr.get_tags[t.name.to_sym].length.should == t.children.length

          child_names = t.children.collect(&:name)
          # Make sure each child name is yield from the tag method
          @pr.tags {|tag_name, classification| child_names.delete(tag_name)}
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
