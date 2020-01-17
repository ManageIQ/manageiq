RSpec.describe MiqApproval do
  it "#approver= also sets approver_name" do
    approval = FactoryBot.build(:miq_approval)
    user     = FactoryBot.create(:user)

    expect(approval.approver_name).to be_nil

    approval.approver = user
    expect(approval.approver_name).to eq(user.name)

    approval.approver = nil
    expect(approval.approver_name).to be_nil
  end

  context "#approve" do
    it "works" do
      user     = FactoryBot.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver = FactoryBot.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')

      approval = FactoryBot.create(:miq_approval)
      reason   = "Why Not?"

      allow(approval).to receive(:authorized?).and_return(false)
      expect { approval.approve(approver, reason) }.to raise_error("not authorized")

      miq_request = FactoryBot.create(:vm_migrate_request, :requester => user)
      approval.miq_request = miq_request
      allow(approval).to receive(:authorized?).and_return(true)
      Timecop.freeze do
        expect(miq_request).to receive(:approval_approved).once
        approval.approve(approver, reason)
        expect(approval.state).to eq('approved')
        expect(approval.reason).to eq(reason)
        expect(approval.stamper).to eq(approver)
        expect(approval.stamper_name).to eq(approver.name)
        expect(approval.stamped_on).to eq(Time.now.utc)
      end
    end

    it "with an approver's own request" do
      vm_template = FactoryBot.create(:template_vmware)
      user        = FactoryBot.create(:user_miq_request_approver)
      request     = FactoryBot.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => vm_template.id, :requester => user)
      approval    = FactoryBot.create(:miq_approval, :miq_request => request)

      expect { approval.approve(user, 'Why Not') }.to_not raise_error
    end

    it "with an approver's object'" do
      vm_template = FactoryBot.create(:template_vmware)
      user        = FactoryBot.create(:user_miq_request_approver)
      request     = FactoryBot.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => vm_template.id, :requester => user)
      approval    = FactoryBot.create(:miq_approval, :miq_request => request)

      expect { approval.approve(user, 'Why Not') }.to_not raise_error
    end
  end

  it "#deny" do
    user     = FactoryBot.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
    approver = FactoryBot.create(:user, :name => 'Wilma Flintstone', :userid => 'approver')

    approval = FactoryBot.create(:miq_approval)
    reason   = "Why Not?"

    allow(approval).to receive(:authorized?).and_return(false)
    expect { approval.deny(approver, reason) }.to raise_error("not authorized")

    miq_request = FactoryBot.create(:vm_migrate_request, :requester => user)
    approval.miq_request = miq_request
    allow(approval).to receive(:authorized?).and_return(true)
    Timecop.freeze do
      expect(miq_request).to receive(:approval_denied).once
      approval.deny(approver, reason)
      expect(approval.state).to eq('denied')
      expect(approval.reason).to eq(reason)
      expect(approval.stamper).to eq(approver)
      expect(approval.stamper_name).to eq(approver.name)
      expect(approval.stamped_on).to eq(Time.now.utc)
    end
  end

  context "#authorized?" do
    let(:approval) { FactoryBot.create(:miq_approval) }
    let(:user)     { FactoryBot.create(:user, :userid => "user1") }
    let(:user2)    { FactoryBot.create(:user, :userid => "user2") }
    let(:approver) { FactoryBot.create(:user_miq_request_approver) }

    it "with nil" do
      expect(approval.authorized?(nil)).to be_falsey
    end

    it "with a user object without approval rights" do
      expect(approval.authorized?(user)).to be_falsey
    end

    it "with a user object with approval rights" do
      expect(approval.authorized?(approver)).to be_truthy
    end

    it "with a userid without approval rights" do
      expect(approval.authorized?(user.userid)).to be_falsey
    end

    it "with a userid with approval rights" do
      expect(approval.authorized?(approver.userid)).to be_truthy
    end

    context "with the approver property set to a specific user" do
      before { approval.approver = user }

      it "and passing the same user" do
        expect(approval.authorized?(user)).to be_truthy
      end

      it "and passing a different user with approval rights" do
        expect(approval.authorized?(approver)).to be_truthy
      end

      it "and passing a different user without approval rights" do
        expect(approval.authorized?(user2)).to be_falsey
      end
    end
  end
end
