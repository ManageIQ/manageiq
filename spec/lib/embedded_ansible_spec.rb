describe EmbeddedAnsible do
  context "with no available subclass" do
    before do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      expect(ContainerOrchestrator).to receive(:available?).and_return(false)
    end

    describe ".new" do
      it "returns an instance of NullEmbeddedAnsible" do
        expect(described_class.new).to be_an_instance_of(NullEmbeddedAnsible)
      end
    end

    describe ".available?" do
      it "returns false" do
        expect(described_class.available?).to be false
      end
    end
  end

  context "in an appliance" do
    before do
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)

      installed_rpms = {
        "ansible-tower-server" => "1.0.1",
        "ansible-tower-setup"  => "1.2.3",
        "vim"                  => "13.5.1"
      }
      expect(LinuxAdmin::Rpm).to receive(:list_installed).and_return(installed_rpms)
    end

    describe ".new" do
      it "returns an instance of ApplianceEmbeddedAnsible" do
        expect(described_class.new).to be_an_instance_of(ApplianceEmbeddedAnsible)
      end
    end

    describe ".available?" do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  context "in Kubernetes/OpenShift" do
    before do
      expect(ContainerOrchestrator).to receive(:available?).and_return(true)
    end

    describe ".new" do
      it "returns an instance of ContainerEmbeddedAnsible" do
        expect(described_class.new).to be_an_instance_of(ContainerEmbeddedAnsible)
      end
    end

    describe ".available?" do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  context "with an miq_databases row" do
    let(:miq_database) { MiqDatabase.first }

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    describe "#alive?" do
      it "returns false if the service is not configured" do
        expect(subject).to receive(:configured?).and_return false
        expect(subject.alive?).to be false
      end

      it "returns false if the service is not running" do
        expect(subject).to receive(:configured?).and_return true
        expect(subject).to receive(:running?).and_return false
        expect(subject.alive?).to be false
      end

      context "when a connection is attempted" do
        let(:api_conn) { double("AnsibleAPIConnection") }
        let(:api) { double("AnsibleAPIResource") }

        before do
          expect(subject).to receive(:configured?).and_return true
          expect(subject).to receive(:running?).and_return true
          expect(subject).to receive(:api_connection).and_return(api_conn)
          expect(api_conn).to receive(:api).and_return(api)

          miq_database.set_ansible_admin_authentication(:password => "adminpassword")
        end

        it "returns false when a AnsibleTowerClient::ConnectionError is raised" do
          error = AnsibleTowerClient::ConnectionError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(subject.alive?).to be false
        end

        it "returns false when a AnsibleTowerClient::SSLError is raised" do
          error = AnsibleTowerClient::SSLError.new("error")
          expect(api).to receive(:verify_credentials).and_raise(error)
          expect(subject.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ConnectionError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ConnectionError)
          expect(subject.alive?).to be false
        end

        it "returns false when an AnsibleTowerClient::ClientError is raised" do
          expect(api).to receive(:verify_credentials).and_raise(AnsibleTowerClient::ClientError)
          expect(subject.alive?).to be false
        end

        it "raises when other errors are raised" do
          expect(api).to receive(:verify_credentials).and_raise(RuntimeError)
          expect { subject.alive? }.to raise_error(RuntimeError)
        end

        it "returns true when no error is raised" do
          expect(api).to receive(:verify_credentials)
          expect(subject.alive?).to be true
        end
      end
    end

    describe "#find_or_create_database_authentication (private)" do
      let(:password)        { "secretpassword" }
      let(:quoted_password) { ActiveRecord::Base.connection.quote(password) }
      let(:connection)      { double(:quote => quoted_password) }

      before do
        allow(connection).to receive(:quote_column_name) do |name|
          ActiveRecord::Base.connection.quote_column_name(name)
        end
      end

      it "creates the database" do
        allow(subject).to receive(:database_connection).and_return(connection)
        expect(subject).to receive(:generate_password).and_return(password)
        expect(connection).to receive(:select_value).with("CREATE ROLE \"awx\" WITH LOGIN PASSWORD #{quoted_password}")
        expect(connection).to receive(:select_value).with("CREATE DATABASE awx OWNER \"awx\" ENCODING 'utf8'")

        auth = subject.send(:find_or_create_database_authentication)
        expect(auth).to have_attributes(:userid => "awx", :password => password)
      end

      it "returns the saved authentication" do
        miq_database.set_ansible_database_authentication(:password => "mypassword")
        auth = subject.send(:find_or_create_database_authentication)
        expect(auth).to have_attributes(:userid => "awx", :password => "mypassword")
      end
    end
  end
end
