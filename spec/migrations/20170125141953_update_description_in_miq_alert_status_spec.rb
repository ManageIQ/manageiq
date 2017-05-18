require_migration

describe UpdateDescriptionInMiqAlertStatus do
  let(:miq_alert_stub) { migration_stub(:MiqAlert) }
  let(:miq_alert_status_stub) { migration_stub(:MiqAlertStatus) }

  migration_context :up do
    it 'it sets miq_alert_status.description using miq_alert.description' do
      ma = miq_alert_stub.create(:description => 'all your base are belong to us!')
      mas = miq_alert_status_stub.create
      ma.miq_alert_statuses = [mas]
      expect(mas.description).to be_nil
      migrate
      mas.reload
      expect(mas.description).to eq('all your base are belong to us!')
    end
  end
end
