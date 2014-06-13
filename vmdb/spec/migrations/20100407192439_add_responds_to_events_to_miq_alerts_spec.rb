require "spec_helper"
require Rails.root.join("db/migrate/20100407192439_add_responds_to_events_to_miq_alerts.rb")

describe AddRespondsToEventsToMiqAlerts do
  migration_context :up do
    let(:miq_alert_stub)  { migration_stub(:MiqAlert) }

    it "adds enabled(false) and responds_to_events columns" do
      alert = miq_alert_stub.create!

      migrate

      alert.reload.enabled.should be_false
    end
  end

end
