describe MiqAlertStatusAction do
  let(:alert) { FactoryGirl.create(:miq_alert_status) }
  let(:user) { FactoryGirl.create(:user) }
  let(:user2) { FactoryGirl.create(:user, :name => 'user2') }

  describe "Validation" do
    it "forbids unknown operations" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'churn', :user => user,
                           :miq_alert_status => alert)
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Action type must be accepted")
    end

    it "must be linked to a user" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'unassign', :user => nil,
                           :miq_alert_status => alert)
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: User can't be blank")
    end

    it "must have a comment if the action_type is comment" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'comment', :user => user, :comment => nil,
                           :miq_alert_status => alert)
      end.to raise_error(ActiveRecord::RecordInvalid,
                         "Validation failed: Comment can't be blank")
    end

    it "can have a comment if the action_type isn't comment" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'unassign', :user => user, :comment => 'Nope.',
                           :miq_alert_status => alert)
      end.to_not raise_error
    end

    it "cannot have an assignee if the action_type is not assign" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'unassign', :user => user, :assignee => user,
                           :miq_alert_status => alert)
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Assignee must be blank")
    end

    it "must have an assignee if the action_type is assign" do
      expect do
        FactoryGirl.create(:miq_alert_status_action, :action_type => 'assign', :user => user, :assignee => nil,
                           :miq_alert_status => alert)
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: Assignee can't be blank")
    end

    it "should allow the currently assigned user to acknoledge the alert" do
      FactoryGirl.create(
        :miq_alert_status_action,
        :action_type      => 'assign',
        :assignee         => user,
        :user             => user,
        :miq_alert_status => alert
      )
      expect do
        FactoryGirl.create(
          :miq_alert_status_action,
          :action_type      => 'acknowledge',
          :user             => user,
          :miq_alert_status => alert
        )
      end.to_not raise_error
    end

    it "should not allow a user not assigned to acknoledge the alert" do
      FactoryGirl.create(
        :miq_alert_status_action,
        :action_type      => 'assign',
        :assignee         => user,
        :user             => user,
        :miq_alert_status => alert
      )
      expect do
        FactoryGirl.create(
          :miq_alert_status_action,
          :action_type      => 'acknowledge',
          :user             => user2,
          :miq_alert_status => alert
        )
      end.to raise_error(ActiveRecord::RecordInvalid, "Validation failed: User that is not assigned cannot acknowledge")
    end
  end
end
