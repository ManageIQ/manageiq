require_migration

describe AddReadOnlyToMiqAlert do
  let(:miq_alert_stub) { migration_stub(:MiqAlert) }

  let(:guids) { described_class::MIQ_ALERT_GUIDS }

  migration_context :up do
    it 'sets read_only to true value in for all records with guid from yaml file' do
      guids.each { |guid| miq_alert_stub.create!(:guid => guid) }

      migrate

      guids.each { |guid| expect(miq_alert_stub.where(:guid => guid).first.reload.read_only).to be_truthy }
    end
  end
end
