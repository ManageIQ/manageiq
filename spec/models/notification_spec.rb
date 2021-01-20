RSpec.describe Notification, :type => :model do
  before { allow(User).to receive_messages(:server_timezone => 'UTC') }
  before { NotificationType.seed }
  let(:tenant) { FactoryBot.create(:tenant) }
  let!(:user) { FactoryBot.create(:user_with_group, :tenant => tenant) }

  describe '.of_type' do
    it "only returns notification of the given type" do
      type_name_one   = "request_approved"
      type_name_two   = "request_denied"
      type_name_three = "vm_retired"

      Notification.create(:type => type_name_one, :initiator => user, :options => {:subject => "Request 1"})
      Notification.create(:type => type_name_one, :initiator => user, :options => {:subject => "Request 2"})
      Notification.create(:type => type_name_two, :initiator => user, :options => {:subject => "Request 3"})

      expect(Notification.of_type(type_name_one).count).to eq(2)
      expect(Notification.of_type(type_name_two).count).to eq(1)
      expect(Notification.of_type(type_name_three).count).to eq(0)
    end
  end

  describe '.emit' do
    context 'successful' do
      let(:vm) { FactoryBot.create(:vm, :tenant => tenant) }
      let(:notification_type) { :vm_retired }

      subject { Notification.create(:type => notification_type, :subject => vm) }

      it 'creates a new notification along with recipients' do
        expect(subject.notification_type.name).to eq(notification_type.to_s)
        expect(subject.subject).to eq(vm)
        expect(subject.recipients).to match_array([user])
        expect(user.notifications.count).to eq(1)
        expect(user.unseen_notifications.count).to eq(1)
      end

      it 'creates single record in notification_recipients table if recipent user belongs to several groups' do
        user.miq_groups << FactoryBot.create(:miq_group, :tenant => tenant)
        expect(subject.recipients).to match_array([user])
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
        let(:limiting_role) { FactoryBot.create(:miq_user_role, :settings => {:restrictions=>{:vms=>:user}}) }
        let(:limited_group) do
          FactoryBot.create(:miq_group, :tenant_type, :tenant => tenant, :miq_user_role => limiting_role)
        end
        let!(:limited_user) { FactoryBot.create(:user, :miq_groups => [limited_group]) }

        it 'emits notifications only to those users, who are authorized to see the subject' do
          expect(subject.recipients).to match_array([user])
        end
      end

      context 'emiting for MiqRequest' do
        let(:friends) { FactoryBot.create(:miq_group) }
        let(:requester) { FactoryBot.create(:user, :miq_groups => [friends]) }
        let!(:peer) { FactoryBot.create(:user, :miq_groups => [friends]) }
        let!(:non_peer) { FactoryBot.create(:user) }
        let(:vm) { FactoryBot.create(:vm_vmware, :name => 'vm', :location => 'abc/def.vmx') }
        let(:request) do
          FactoryBot.create(:miq_provision_request, :requester => requester, :src_vm_id => vm.id,
                             :options => {:owner_email => 'tester@miq.com'})
        end
        subject { Notification.create(:subject => request, :type => 'request_approved') }

        it 'subscribes only users of the group' do
          expect(subject.recipients).to match_array([requester, peer])
        end
      end

      context 'subject does not have tenant' do
        let!(:peer) { FactoryBot.create(:user_with_group, :tenant => tenant) }
        let!(:non_peer) { FactoryBot.create(:user) }

        subject { Notification.create(:initiator => user, :type => 'automate_tenant_info', :options => {:message => "This is not the message you are looking for."}) }

        it 'sends notification to the tenant of initiator' do
          expect(subject.recipients).to match_array([user, peer])
        end
      end
    end
  end

  describe '#to_h' do
    let(:notification) { FactoryBot.create(:notification, :initiator => user, :options => {:extra => 'information'}) }
    it 'contains information consumable by UI' do
      expect(notification.to_h).to include(
        :level      => notification.notification_type.level,
        :created_at => notification.created_at,
        :text       => notification.notification_type.message,
        :bindings   => a_hash_including(:initiator => a_hash_including(:text => user.name),
                                        :extra     => a_hash_including(:text => 'information')
                                       )
      )
    end

    context 'link_to is set' do
      let(:notification) do
        FactoryBot.create(:notification, :initiator         => user,
                                          :notification_type => FactoryBot.create(:notification_type, :link_to => 'initiator'))
      end

      it 'contains the link to the initiator' do
        expect(notification.to_h).to include(:bindings => a_hash_including(:link => a_hash_including(:model => 'User', :id => user.id)))
      end
    end

    context "subject text" do
      let(:vm) { FactoryBot.create(:vm, :tenant => tenant) }
      subject { Notification.create(:type => :vm_snapshot_failure, :subject => vm, :options => {:error => "oops", :snapshot_op => "create"}) }

      it "stuffs subject into options hash in case the subject is destroyed" do
        expect(subject.options[:subject]).to eql(subject.subject.name)
      end

      it "detects a rename of the subject" do
        subject
        vm_name = "#{vm.name}_1"
        vm.update(:name => vm_name)

        note = Notification.first
        expect(note.to_h.fetch_path(:bindings, :subject, :text)).to eql(vm_name)
      end

      it "retains name incase subject is destroyed" do
        subject
        vm_name = vm.name
        vm.destroy

        note = Notification.first
        expect(note.to_h.fetch_path(:bindings, :subject, :text)).to eql(vm_name)
      end

      it "doesn't detect subject rename if subject is destroyed" do
        subject
        original_name = vm.name
        vm_name = "#{vm.name}_1"
        vm.update(:name => vm_name)
        vm.destroy

        note = Notification.first
        expect(note.to_h.fetch_path(:bindings, :subject, :text)).to eql(original_name)
      end
    end
  end

  describe "#seen_by_all_recipients?" do
    let(:notification) { FactoryBot.create(:notification, :initiator => user) }

    it "is false if a user has not seen the notification" do
      expect(notification.seen_by_all_recipients?).to be_falsey
    end

    it "is true when all recipients have seen the notification" do
      notification.notification_recipients.each { |r| r.update(:seen => true) }
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

    it 'does not lookup notification type without event or full_data' do
      NotificationType.names
      expect do
        Notification.notification_text(nil, nil)
        Notification.notification_text('abc', nil)
        Notification.notification_text(nil, {})
      end.to_not make_database_queries
    end

    it 'applies message' do
      full_data = {:subject => 'vm1'}
      expect(Notification.notification_text('vm_retired', full_data)).to eq("Virtual Machine vm1 has been retired.")
    end
  end
end
