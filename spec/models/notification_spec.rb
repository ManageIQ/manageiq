describe Notification, :type => :model do
  before { allow(User).to receive_messages(:server_timezone => 'UTC') }
  before { NotificationType.seed }
  let(:tenant) { FactoryGirl.create(:tenant) }
  let!(:user) { FactoryGirl.create(:user_with_group, :tenant => tenant) }

  describe '.of_type' do
    it "only returns notification of the given type" do
      types = NotificationType.all
      type_name_one   = types[0].name
      type_name_two   = types[1].name
      type_name_three = types[2].name

      Notification.create(:type => type_name_one, :initiator => user)
      Notification.create(:type => type_name_one, :initiator => user)
      Notification.create(:type => type_name_two, :initiator => user)

      expect(Notification.of_type(type_name_one).count).to eq(2)
      expect(Notification.of_type(type_name_two).count).to eq(1)
      expect(Notification.of_type(type_name_three).count).to eq(0)
    end
  end

  describe '.emit' do
    context 'successful' do
      let(:vm) { FactoryGirl.create(:vm, :tenant => tenant) }
      let(:notification_type) { :vm_retired }

      subject { Notification.create(:type => notification_type, :subject => vm) }

      it 'creates a new notification along with recipients' do
        expect(subject.notification_type.name).to eq(notification_type.to_s)
        expect(subject.subject).to eq(vm)
        expect(subject.recipients).to match_array([user])
        expect(user.notifications.count).to eq(1)
        expect(user.unseen_notifications.count).to eq(1)
      end

      context 'asynchronous notifications' do
        before { stub_settings(:server => {:asynchronous_notifications => async}) }
        context 'enabled' do
          let(:async) { true }

          it 'broadcasts the message through ActionCable' do
            expect_any_instance_of(ActionCable::Server::Base).to receive(:broadcast)
            subject # force the creation of the db object
          end
        end

        context 'disabled' do
          let(:async) { false }

          it 'broadcasts the message through ActionCable' do
            expect_any_instance_of(ActionCable::Server::Base).not_to receive(:broadcast)
            subject # force the creation of the db object
          end
        end
      end

      context 'tenant includes user without access to the subject (vm)' do
        let(:limiting_role) { FactoryGirl.create(:miq_user_role, :settings => {:restrictions=>{:vms=>:user}}) }
        let(:limited_group) do
          FactoryGirl.create(:miq_group, :tenant_type, :tenant => tenant, :miq_user_role => limiting_role)
        end
        let!(:limited_user) { FactoryGirl.create(:user, :miq_groups => [limited_group]) }

        it 'emits notifications only to those users, who are authorized to see the subject' do
          expect(subject.recipients).to match_array([user])
        end
      end

      context 'emiting for MiqRequest' do
        let(:friends) { FactoryGirl.create(:miq_group) }
        let(:requester) { FactoryGirl.create(:user, :miq_groups => [friends]) }
        let!(:peer) { FactoryGirl.create(:user, :miq_groups => [friends]) }
        let!(:non_peer) { FactoryGirl.create(:user) }
        let(:vm) { FactoryGirl.create(:vm_vmware, :name => 'vm', :location => 'abc/def.vmx') }
        let(:request) do
          FactoryGirl.create(:miq_provision_request, :requester => requester, :src_vm_id => vm.id,
                             :options => {:owner_email => 'tester@miq.com'})
        end
        subject { Notification.create(:subject => request, :type => 'request_approved') }

        it 'subscribes only users of the group' do
          expect(subject.recipients).to match_array([requester, peer])
        end
      end

      context 'subject does not have tenant' do
        let!(:peer) { FactoryGirl.create(:user_with_group, :tenant => tenant) }
        let!(:non_peer) { FactoryGirl.create(:user) }

        subject { Notification.create(:initiator => user, :type => 'automate_tenant_info') }

        it 'sends notification to the tenant of initiator' do
          expect(subject.recipients).to match_array([user, peer])
        end
      end
    end
  end

  describe '#to_h' do
    let(:notification) { FactoryGirl.create(:notification, :initiator => user, :options => {:extra => 'information'}) }
    it 'contains information consumable by UI' do
      expect(notification.to_h).to include(
        :level      => notification.notification_type.level,
        :created_at => notification.created_at,
        :text       => notification.notification_type.message,
        :bindings   => a_hash_including(:initiator => a_hash_including(:text => user.name,
                                                                       :link => a_hash_including(:id, :model)),
                                        :extra     => a_hash_including(:text => 'information')
                                       )
      )
    end
  end

  describe "#seen_by_all_recipients?" do
    let(:notification) { FactoryGirl.create(:notification, :initiator => user) }

    it "is false if a user has not seen the notification" do
      expect(notification.seen_by_all_recipients?).to be_falsey
    end

    it "is true when all recipients have seen the notification" do
      notification.notification_recipients.each { |r| r.update_attributes(:seen => true) }
      expect(notification.seen_by_all_recipients?).to be_truthy
    end

    it "is true when there are no recipients" do
      notification.notification_recipients.destroy_all
      expect(notification.seen_by_all_recipients?).to be_truthy
    end
  end

  describe '.notification_text' do
    before do
      NotificationType.instance_variable_set(:@names, nil)
      NotificationType.seed if NotificationType.all.empty?
    end

    it 'does not lookup notificaiton type without event or full_data' do
      NotificationType.names
      expect do
        Notification.notification_text(nil, nil)
        Notification.notification_text('abc', nil)
        Notification.notification_text(nil, {})
      end.to match_query_limit_of(0)
    end

    it 'applies message' do
      full_data = {:subject => 'vm1'}
      expect(Notification.notification_text('vm_retired', full_data)).to eq("Virtual Machine vm1 has been retired.")
    end
  end
end
