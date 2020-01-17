RSpec.describe MiqAlertStatus do
  let(:ems)                    { FactoryBot.create(:ems_vmware, :name => 'ems') }
  let(:alert)                  { FactoryBot.create(:miq_alert_status) }
  let(:user1)                  { FactoryBot.create(:user, :name => 'user1') }
  let(:user2)                  { FactoryBot.create(:user, :name => 'user2') }
  let(:acknowledgement_action) do
    FactoryBot.create(:miq_alert_status_action, :action_type => 'acknowledge', :user => user1,
                       :miq_alert_status => alert)
  end
  let(:assignment_action) do
    FactoryBot.create(:miq_alert_status_action, :action_type => 'assign', :user => user1, :assignee => user1,
                       :miq_alert_status => alert)
  end
  let(:hide_action) do
    FactoryBot.create(:miq_alert_status_action, :action_type => 'hide', :user => user1, :miq_alert_status => alert)
  end
  let(:show_action) do
    FactoryBot.create(:miq_alert_status_action, :action_type => 'show', :user => user1, :miq_alert_status => alert)
  end

  describe "Validation" do
    it "should reject unexpected severities" do
      expect do
        FactoryBot.create(:miq_alert_status, :severity => 'awesome')
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: MiqAlertStatus: Severity must be accepted")
    end
  end

  describe "#acknowledged?" do
    it "should return false if there is no acknolegment history" do
      expect(alert.acknowledged?).to be_falsey
    end

    it "should return true if acknowledged" do
      alert.miq_alert_status_actions << assignment_action
      Timecop.travel 1.minute do
        alert.miq_alert_status_actions << acknowledgement_action
      end
      expect(alert.acknowledged?).to be_truthy
      alert.save
      expect(alert.acknowledged?).to be_truthy
    end

    it "should return false if unacknowledged" do
      alert.miq_alert_status_actions << assignment_action
      alert.save
      alert.reload
      Timecop.travel 1.minute do
        alert.miq_alert_status_actions << acknowledgement_action
      end
      Timecop.travel 2.minutes do
        FactoryBot.create(
          :miq_alert_status_action,
          :action_type      => 'unacknowledge',
          :user             => user1,
          :miq_alert_status => alert
        )
      end
      alert.reload
      expect(alert.acknowledged?).to be_falsey
    end

    it "should return false if reassigned after acknowledgement" do
      alert.miq_alert_status_actions << assignment_action
      Timecop.travel 1.minute do
        alert.miq_alert_status_actions << acknowledgement_action
      end
      Timecop.travel 2.minutes do
        alert.miq_alert_status_actions << FactoryBot.create(
          :miq_alert_status_action,
          :action_type      => 'assign',
          :user             => user1,
          :assignee         => user2,
          :miq_alert_status => alert
        )
        expect(alert.acknowledged?).to be_falsey
        alert.save
        alert.reload
        expect(alert.acknowledged?).to be_falsey
      end

      expect(alert.acknowledged?).to be_falsey
    end
  end

  describe "#assignee" do
    it "should return the last asignee" do
      expect(alert.assignee).to be_nil
      alert.miq_alert_status_actions = [assignment_action]
      expect(alert.assignee).to eq(user1)
      Timecop.travel 1.minute do
        FactoryBot.create(
          :miq_alert_status_action,
          :action_type      => 'assign',
          :user             => user1,
          :miq_alert_status => alert,
          :assignee         => user2
        )
      end
      alert.reload
      expect(alert.assignee).to eq(user2)
      Timecop.travel 2.minutes do
        FactoryBot.create(
          :miq_alert_status_action,
          :action_type      => 'unassign',
          :user             => user1,
          :miq_alert_status => alert
        )
      end
      alert.reload
      expect(alert.assignee).to be_nil
    end
  end

  describe "#hidden?" do
    it "returns false for new" do
      expect(alert.hidden?).to be_falsey
    end

    it "returns true after hide action" do
      alert.miq_alert_status_actions = [assignment_action, hide_action]
      expect(alert.hidden?).to be_truthy
    end

    it "returns false after show action" do
      alert.miq_alert_status_actions = [assignment_action, hide_action, show_action]
      expect(alert.hidden?).to be_falsey
    end
  end
end
