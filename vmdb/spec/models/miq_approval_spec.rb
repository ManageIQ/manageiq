require "spec_helper"

describe MiqApproval do
  it "#approver= also sets approver_name" do
    approval = FactoryGirl.build(:miq_approval)
    user     = FactoryGirl.create(:user)

    approval.approver_name.should be_nil

    approval.approver = user
    approval.approver_name.should == user.name

    approval.approver = nil
    approval.approver_name.should be_nil
  end

  context "#approve" do
    it "works" do
      user     = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')

      approval = FactoryGirl.create(:miq_approval)
      reason   = "Why Not?"

      approval.stub(:authorized?).and_return(false)
      lambda { approval.approve(approver.userid, reason) }.should raise_error("not authorized")

      miq_request = FactoryGirl.create(:miq_request, :requester => user)
      approval.miq_request = miq_request
      approval.stub(:authorized?).and_return(true)
      Timecop.freeze do
        miq_request.should_receive(:approval_approved).once
        approval.approve(approver.userid, reason)
        approval.state.should        == 'approved'
        approval.reason.should       == reason
        approval.stamper.should      == approver
        approval.stamper_name.should == approver.name
        approval.stamped_on.should   == Time.now.utc
      end
    end

    it "with an approver's own request" do
      vm_template = FactoryGirl.create(:template_vmware)
      user        = FactoryGirl.create(:user_miq_request_approver)
      request     = FactoryGirl.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => vm_template.id, :userid => user.userid)
      approval    = FactoryGirl.create(:miq_approval, :miq_request => request)

      expect { approval.approve(user.userid, 'Why Not') }.to_not raise_error
    end
  end

  it "#deny" do
    user     = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')

    approval = FactoryGirl.create(:miq_approval)
    reason   = "Why Not?"

    approval.stub(:authorized?).and_return(false)
    lambda { approval.deny(approver.userid, reason) }.should raise_error("not authorized")

    miq_request = FactoryGirl.create(:miq_request, :requester => user)
    approval.miq_request = miq_request
    approval.stub(:authorized?).and_return(true)
    Timecop.freeze do
      miq_request.should_receive(:approval_denied).once
      approval.deny(approver.userid, reason)
      approval.state.should        == 'denied'
      approval.reason.should       == reason
      approval.stamper.should      == approver
      approval.stamper_name.should == approver.name
      approval.stamped_on.should   == Time.now.utc
    end
  end

  context "#authorized?" do
    let(:approval) { FactoryGirl.create(:miq_approval) }
    let(:user)     { FactoryGirl.create(:user, :userid => "user1") }
    let(:user2)    { FactoryGirl.create(:user, :userid => "user2") }
    let(:approver) { FactoryGirl.create(:user_miq_request_approver) }

    it "with nil" do
      approval.authorized?(nil).should be_false
    end

    it "with a user object without approval rights" do
      approval.authorized?(user).should be_false
    end

    it "with a user object with approval rights" do
      approval.authorized?(approver).should be_true
    end

    it "with a userid without approval rights" do
      approval.authorized?(user.userid).should be_false
    end

    it "with a userid with approval rights" do
      approval.authorized?(approver.userid).should be_true
    end

    context "with the approver property set to a specific user" do
      before { approval.approver = user }

      it "and passing the same user" do
        approval.authorized?(user).should be_true
      end

      it "and passing a different user with approval rights" do
        approval.authorized?(approver).should be_true
      end

      it "and passing a different user without approval rights" do
        approval.authorized?(user2).should be_false
      end
    end
  end
end
