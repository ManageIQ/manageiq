require "spec_helper"

describe MiqApproval do

  it "#set_approver_delegates" do
    approval = FactoryGirl.build(:miq_approval)
    approval.approver_name.should be_nil
    approval.approver_type.should be_nil
    approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")
    approval.approver = approver_role
    approval.set_approver_delegates
    approval.approver_name.should == approver_role.name
    approval.approver_type.should == approver_role.class.name
  end

  it "#approve" do
    user          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver      = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
    approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")

    approval = FactoryGirl.create(:miq_approval, :approver => approver_role)
    reason   = "Why Not?"

    approval.stub(:authorized?).and_return(false)
    lambda { approval.approve(approver.userid, reason) }.should raise_error("not authorized")

    miq_request = FactoryGirl.create(:miq_request, :requester => user)
    approval.miq_request = miq_request
    approval.stub(:authorized?).and_return(true)
    now = Time.now
    Time.stub(:now).and_return(now)
    miq_request.should_receive(:approval_approved).once
    approval.approve(approver.userid, reason)
    approval.state.should        == 'approved'
    approval.reason.should       == reason
    approval.stamper.should      == approver
    approval.stamper_name.should == approver.name
    approval.stamped_on.should   == now.utc
  end

  it "#deny" do
    user          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver      = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
    approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")

    approval = FactoryGirl.create(:miq_approval, :approver => approver_role)
    reason   = "Why Not?"

    approval.stub(:authorized?).and_return(false)
    lambda { approval.deny(approver.userid, reason) }.should raise_error("not authorized")

    miq_request = FactoryGirl.create(:miq_request, :requester => user)
    approval.miq_request = miq_request
    approval.stub(:authorized?).and_return(true)
    now = Time.now
    Time.stub(:now).and_return(now)
    miq_request.should_receive(:approval_denied).once
    approval.deny(approver.userid, reason)
    approval.state.should        == 'denied'
    approval.reason.should       == reason
    approval.stamper.should      == approver
    approval.stamper_name.should == approver.name
    approval.stamped_on.should   == now.utc
  end

  it "#authorized?" do
    MiqRegion.seed
    MiqProductFeature.seed
    MiqUserRole.seed

    user          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver      = FactoryGirl.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')
    approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")
    approval      = FactoryGirl.create(:miq_approval, :approver => approver_role)

    approval.authorized?(nil).should be_false
    approval.authorized?('anyone').should be_false

    approver.stub(:miq_user_role).and_return(MiqUserRole.find_by_name('EvmRole-super_administrator'))
    approval.authorized?(approver).should be_true
    approver.stub(:miq_user_role).and_return(MiqUserRole.find_by_name('EvmRole-administrator'))
    approval.authorized?(approver).should be_true

    approver.stub(:miq_user_role).and_return(MiqUserRole.find_by_name('foo'))

    approval.approver = approver
    approval.authorized?(approver).should be_true
    approval.authorized?(user).should be_false

    approval.approver = approver_role
    approver.stub(:role).and_return(approver_role)
    approval.authorized?(approver).should be_true

    approver.stub(:role).and_return(nil)
    approval.authorized?(approver).should be_false
  end

  context "should approve an approver's own request (FB15633)" do
    before(:each) do
      MiqRegion.seed
      MiqProductFeature.seed

      idents = ["miq_request_view", "miq_request_control"]
      @miq_user_role  = FactoryGirl.create(:miq_user_role, :name => 'cloud', :miq_product_features => MiqProductFeature.find_all_by_identifier(idents))

      @group = FactoryGirl.create(:miq_group, :description => 'Cloud Group', :miq_user_role => @miq_user_role)
      @user  = FactoryGirl.create(:user, :name => 'cloud', :miq_groups => [@group])

      @approver_role = UiTaskSet.create(:name => "approver", :description => "Approver")
      @vm_template   = FactoryGirl.create(:template_vmware)
      @request = FactoryGirl.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => @vm_template.id, :userid => @user.userid)

      @approval = FactoryGirl.create(:miq_approval, :approver => @approver_role)
      @approval.miq_request = @request
    end

    it "#authorized?" do
      @approval.authorized?(@user).should be_true
    end

    it "#approve" do
      lambda {@approval.approve(@user.userid, 'Why Not')}.should_not raise_error
    end
  end
end
