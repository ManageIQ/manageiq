describe 'Notifications API' do
  let(:foreign_user) { FactoryGirl.create(:user) }
  let(:notification) { FactoryGirl.create(:notification, :initiator => @user) }
  let(:foreign_notification) { FactoryGirl.create(:notification, :initiator => foreign_user) }
  let(:notification_recipient) { notification.notification_recipients.first }
  let(:notification_url) { notifications_url(notification_recipient.id) }

  describe 'notification create' do
    it 'is not supported' do
      api_basic_authorize

      run_post(notifications_url, gen_request(:create, :notification_id => 1, :user_id => 1))
      expect_bad_request(/Unsupported Action create/i)
    end
  end

  describe 'notification edit' do
    it 'is not supported' do
      api_basic_authorize

      run_post(notifications_url, gen_request(:edit, :user_id => 1, :href => notification_url))
      expect_bad_request(/Unsupported Action edit/i)
    end
  end

  describe 'notification delete' do
    it 'is not supported' do
      api_basic_authorize

      run_post(notifications_url, gen_request(:delete, :href => notification_url))
      expect_bad_request(/Unsupported Action delete/i)
    end
  end

  describe 'mark_as_seen' do
    subject { notification_recipient.seen }
    it 'rejects on notification that is not owned by current user' do
      api_basic_authorize

      run_post(notifications_url(foreign_notification.notification_recipient_ids.first), gen_request(:mark_as_seen))
      expect(response).to have_http_status(:not_found)
    end

    it 'marks single notification seen and returns success' do
      api_basic_authorize

      expect(notification_recipient.seen).to be_falsey
      run_post(notification_url, gen_request(:mark_as_seen))
      expect_single_action_result(:success => true, :href => :notification_url)
      expect(notification_recipient.reload.seen).to be_truthy
    end
  end
end
