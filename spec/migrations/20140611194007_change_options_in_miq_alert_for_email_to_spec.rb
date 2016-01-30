require_migration

describe ChangeOptionsInMiqAlertForEmailTo do
  migration_context :up do
    let(:miq_alert_stub) { migration_stub(:MiqAlert) }

    it 'default string type miq_alert email is converted to the empty array' do
      options = {:notifications => {:email => {:to => ''}}}
      alert = miq_alert_stub.create!(:description => 'Test Alert', :options => options)

      migrate

      alert.reload
      expect(alert.options).to eq(:notifications => {:email => {:to => []}})
    end

    it 'existing string type miq_alert emails are converted to an array' do
      options = {:notifications => {:email => {:to => "mail1\nmail2\n"}}}
      alert = miq_alert_stub.create!(:description => 'Test Alert', :options => options)

      migrate

      alert.reload
      expect(alert.options).to eq(:notifications => {:email => {:to => %w(mail1 mail2)}})
    end

    it 'existing array type miq_alert emails remain unchanged' do
      options = {:notifications => {:email => {:to => []}}}
      alert = miq_alert_stub.create!(:description => 'Test Alert', :options => options)

      migrate

      alert.reload
      expect(alert.options).to eq(options)
    end
  end
end
