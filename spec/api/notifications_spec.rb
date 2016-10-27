describe 'Notifications API' do
  let(:foreign_user) { FactoryGirl.create(:user) }
  let(:notification) { FactoryGirl.create(:notification, :initiator => @user) }
  let(:foreign_notification) { FactoryGirl.create(:notification, :initiator => foreign_user) }
  let(:notification_recipient) { notification.notification_recipients.first }
  let(:notification_url) { notifications_url(notification_recipient.id) }
  let(:foreign_notification_url) { notifications_url(foreign_notification.notification_recipient_ids.first) }

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
    context 'on resource' do
      it 'deletes notification using POST' do
        api_basic_authorize

        run_post(notification_url, gen_request(:delete))
        expect(response).to have_http_status(:ok)
        expect_single_action_result(:success => true, :href => notification_url)
        expect { notification_recipient.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'deletes notification using DELETE' do
        api_basic_authorize

        run_delete(notification_url)
        expect(response).to have_http_status(:no_content)
        expect { notification_recipient.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'on collection' do
      it 'rejects on notification that is not owned by current user' do
        api_basic_authorize

        run_post(notifications_url, gen_request(:delete, :href => foreign_notification_url))
        expect(response).to have_http_status(:not_found)
      end

      it 'deletes single' do
        api_basic_authorize

        run_post(notifications_url, gen_request(:delete, :href => notification_url))
        expect(response).to have_http_status(:ok)
        expect_results_to_match_hash('results', [{'success' => true, 'href' => notification_url}])
        expect { notification_recipient.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      let(:notification2) { FactoryGirl.create(:notification, :initiator => @user) }
      let(:notification2_recipient) { notification2.notification_recipients.first }
      let(:notification2_url) { notifications_url(notification2_recipient.id) }

      it 'deletes multiple' do
        api_basic_authorize
        run_post(notifications_url, gen_request(:delete, [{:href => notification_url}, {:href => notification2_url}]))
        expect(response).to have_http_status(:ok)
        expect { notification_recipient.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { notification2_recipient.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'compressed id' do
        let(:notification_id) { ApplicationRecord.compress_id(notification_recipient.id) }
        it 'deletes notifications specified by compressed id in href' do
          api_basic_authorize
          run_post(notifications_url, gen_request(:delete, :href => notifications_url(notification_id)))
          expect(response).to have_http_status(:ok)
        end

        it 'deletes notifications specified by compressed id' do
          api_basic_authorize
          run_post(notifications_url, gen_request(:delete, :id => notification_id))
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'mark_as_seen' do
    subject { notification_recipient.seen }
    it 'rejects on notification that is not owned by current user' do
      api_basic_authorize

      run_post(foreign_notification_url, gen_request(:mark_as_seen))
      expect(response).to have_http_status(:not_found)
    end

    it 'marks single notification seen and returns success' do
      api_basic_authorize

      expect(notification_recipient.seen).to be_falsey
      run_post(notification_url, gen_request(:mark_as_seen))
      expect_single_action_result(:success => true, :href => notification_url)
      expect(notification_recipient.reload.seen).to be_truthy
    end
  end
end
