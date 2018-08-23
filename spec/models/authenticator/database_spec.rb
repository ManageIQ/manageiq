describe Authenticator::Database do
  subject { Authenticator::Database.new({}) }
  let!(:alice) { FactoryGirl.create(:user, :userid => 'alice', :password => 'secret') }
  let!(:vincent) { FactoryGirl.create(:user, :userid => 'Vincent', :password => 'secret') }

  describe '#uses_stored_password?' do
    it "is true" do
      expect(subject.uses_stored_password?).to be_truthy
    end
  end

  describe '#lookup_by_identity' do
    it "finds existing users" do
      expect(subject.lookup_by_identity('alice')).to be_truthy
    end

    it "doesn't create new users" do
      expect(subject.lookup_by_identity('bob')).not_to be
    end
  end

  describe '#authenticate' do
    def authenticate
      subject.authenticate(username, password)
    end

    let(:username) { 'alice' }
    let(:password) { 'secret' }

    context "with correct password" do
      it "succeeds" do
        expect(authenticate).to eq(alice)
      end

      it "records two successful audit entries" do
        expect(AuditEvent).to receive(:success).with(
          :event   => 'authenticate_database',
          :userid  => 'alice',
          :message => "User alice successfully validated by EVM",
        )
        expect(AuditEvent).to receive(:success).with(
          :event   => 'authenticate_database',
          :userid  => 'alice',
          :message => "Authentication successful for user alice",
        )
        expect(AuditEvent).not_to receive(:failure)
        authenticate
      end
      it "updates lastlogon" do
        expect(-> { authenticate }).to change { alice.reload.lastlogon }
      end
    end

    context "with bad password" do
      let(:password) { 'incorrect' }

      before do
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError, "Authentication failed")
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_database',
          :userid  => 'alice',
          :message => "Authentication failed for userid alice",
        )
        expect(AuditEvent).not_to receive(:success)
        authenticate rescue nil
      end

      it "logs the failure" do
        allow($log).to receive(:warn).with(/Audit/)
        expect($log).to receive(:warn).with(/Authentication failed$/)
        authenticate rescue nil
      end

      it "doesn't change lastlogon" do
        expect(-> { authenticate rescue nil }).not_to change { alice.reload.lastlogon }
      end
    end

    context "with unknown username" do
      let(:username) { 'bob' }

      before do
        EvmSpecHelper.create_guid_miq_server_zone
      end

      it "fails" do
        expect(-> { authenticate }).to raise_error(MiqException::MiqEVMLoginError)
      end

      it "records one failing audit entry" do
        expect(AuditEvent).to receive(:failure).with(
          :event   => 'authenticate_database',
          :userid  => 'bob',
          :message => "Authentication failed for userid bob",
        )
        expect(AuditEvent).not_to receive(:success)
        authenticate rescue nil
      end

      it "logs the failure" do
        allow($log).to receive(:warn).with(/Audit/)
        expect($log).to receive(:warn).with(/Authentication failed$/)
        authenticate rescue nil
      end
    end

    context "with mixed case username" do
      let(:username) { 'vInCeNt' }

      it "succeeds" do
        expect(authenticate).to eq(vincent)
      end

      it "records two successful audit entries" do
        expect(AuditEvent).to receive(:success).with(
          :event   => 'authenticate_database',
          :userid  => 'vincent',
          :message => "User vincent successfully validated by EVM",
        )
        expect(AuditEvent).to receive(:success).with(
          :event   => 'authenticate_database',
          :userid  => 'vincent',
          :message => "Authentication successful for user vincent",
        )
        expect(AuditEvent).not_to receive(:failure)
        authenticate
      end
      it "updates lastlogon" do
        expect(-> { authenticate }).to change { vincent.reload.lastlogon }
      end
    end
  end
end
