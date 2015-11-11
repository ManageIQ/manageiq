require "spec_helper"

describe MiqHostProvisionRequest do
  it "validates userid" do
    expect { FactoryGirl.create(:miq_host_provision_request, :userid => 'barney') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "validates a requester is specified" do
    expect { FactoryGirl.create(:miq_host_provision_request) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  context "with a valid userid and host," do
    before(:each) do
      @user = FactoryGirl.create(:user, :role => "admin")
      # approver is also an admin
      @approver = FactoryGirl.create(:user_miq_request_approver, :miq_groups => @user.miq_groups)

      @pr = FactoryGirl.create(:miq_host_provision_request, :requester => @user)
    end

    it "should create an MiqHostProvisionRequest" do
      expect(MiqHostProvisionRequest.all).to eq([@pr])
      expect(@pr).to be_valid
      expect(@pr).not_to be_approved
    end

    it "should create a valid MiqRequest" do
      @pr.miq_request.should == MiqRequest.first
      @pr.miq_request.valid?.should be_true
      @pr.miq_request.approval_state.should == "pending_approval"
      @pr.miq_request.resource.should == @pr
      @pr.miq_request.requester_userid.should == @user.userid
      @pr.miq_request.stamped_on.should be_nil

      expect(@pr.miq_request).not_to be_approved
      expect(MiqApproval.all).to eq([@pr.miq_request.first_approval])
    end

    it "should return a workflow class" do
      @pr.workflow_class.should == MiqHostProvisionWorkflow
    end

    context "when calling call_automate_event_queue" do
      before(:each) do
        EvmSpecHelper.local_miq_server(:zone => Zone.seed)
        @pr.miq_request.call_automate_event_queue("request_created")
      end

      it "should create proper MiqQueue item" do
        MiqQueue.count.should == 1
        q = MiqQueue.first
        q.class_name.should == @pr.miq_request.class.name
        q.instance_id.should == @pr.miq_request.id
        q.method_name.should == "call_automate_event"
        q.args.should == %w(request_created)
        q.zone.should == "default"
      end
    end

    context "after MiqRequest is deleted," do
      before(:each) do
        @pr.miq_request.destroy
      end

      it "should delete MiqHostProvisionRequest" do
        MiqHostProvisionRequest.count.should == 0
      end

      it "should delete MiqApproval" do
        MiqApproval.count.should == 0
      end

      it "should not delete Approver" do
        expect { @approver.reload }.not_to raise_error
      end
    end

    context "when processing tags" do
      before do
        FactoryGirl.create(:classification_department_with_tags)
      end

      it "should add and delete tags from a request" do
        @pr.get_tags.length.should == 0

        t = Classification.where(:description => 'Department', :parent_id => 0).includes(:tag).first
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

        t = Classification.where(:description => 'Department', :parent_id => 0).includes(:tag).first
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

  context "#placement_ems" do
    it "finds placement_ems" do
      ems = FactoryGirl.create(:ext_management_system)
      expect(request(:options => {:placement_ems_name => [ems.id, 'name']}).placement_ems).to eq(ems)
    end

    it "handles nothing defined" do
      expect(request.placement_ems).not_to be
    end
  end

  context "#placement_cluster" do
    it "finds placement_cluster" do
      cluster = FactoryGirl.create(:ems_cluster)
      expect(request(:options => {:placement_cluster_name => [cluster.id, 'name']}).placement_cluster).to eq(cluster)
    end

    it "handles nothing defined" do
      expect(request.placement_cluster).not_to be
    end
  end

  context "#placement_folder" do
    it "finds placement_folder" do
      folder = FactoryGirl.create(:ems_folder)
      expect(request(:options => {:placement_folder_name => [folder.id, 'name']}).placement_folder).to eq(folder)
    end

    it "handles nothing defined" do
      expect(request.placement_folder).not_to be
    end
  end

  context "#pxe_server" do
    it "finds pxe_server" do
      pxe_server = FactoryGirl.create(:pxe_server)
      expect(request(:options => {:pxe_server_id => [pxe_server.id, 'name']}).pxe_server).to eq(pxe_server)
    end

    it "handles nothing defined" do
      expect(request.pxe_server).not_to be
    end
  end

  context "#pxe_image" do
    it "finds pxe_image" do
      pxe_image = FactoryGirl.create(:pxe_image)
      expect(request(:options => {:pxe_image_id => [pxe_image.id, 'name']}).pxe_image).to eq(pxe_image)
    end

    it "handles nothing defined" do
      expect(request.pxe_image).not_to be
    end
  end

  private

  def request(params = {})
    FactoryGirl.create(:miq_host_provision_request, params.merge(:requester => FactoryGirl.create(:user)))
  end
end
