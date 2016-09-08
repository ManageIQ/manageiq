describe Notification, :type => :model do
  before { NotificationType.seed }
  describe '.emit' do
    context 'successful' do
      let(:tenant) { FactoryGirl.create(:tenant) }
      let(:vm) { FactoryGirl.create(:vm, :tenant => tenant) }
      let!(:user) { FactoryGirl.create(:user_with_group, :tenant => tenant) }
      let(:notification_type) { :vm_powered_on }

      subject { Notification.create(:type => notification_type, :subject => vm) }

      it 'creates a new notification along with recipients' do
        expect(subject.notification_type.name).to eq(notification_type.to_s)
        expect(subject.subject).to eq(vm)
        expect(subject.recipients).to match_array([user])
        expect(user.notifications.count).to eq(1)
        expect(user.unseen_notifications.count).to eq(1)
      end
    end
  end
end
