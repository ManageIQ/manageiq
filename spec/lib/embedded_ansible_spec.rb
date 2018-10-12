require 'docker'

describe EmbeddedAnsible do
  describe ".<=>" do
    it "allows classes to be sorted by priority" do
      expect(EmbeddedAnsible.subclasses.sort).to eq([ApplianceEmbeddedAnsible, ContainerEmbeddedAnsible, DockerEmbeddedAnsible, NullEmbeddedAnsible])
    end
  end

  context "with no available subclass" do
    before do
      expect(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      expect(ContainerOrchestrator).to receive(:available?).and_return(false)
      expect(Docker).to receive(:validate_version!).and_raise(RuntimeError)
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
      allow(ContainerOrchestrator).to receive(:available?).and_return(false)
      allow(Docker).to receive(:validate_version!).and_raise(RuntimeError)

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
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      allow(Docker).to receive(:validate_version!).and_raise(RuntimeError)
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

  context "when using docker" do
    before do
      allow(ContainerOrchestrator).to receive(:available?).and_return(false)
      allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
      allow(Docker).to receive(:validate_version!).and_return(true)
    end

    describe ".new" do
      it "returns an instance of DockerEmbeddedAnsible" do
        expect(described_class.new).to be_an_instance_of(DockerEmbeddedAnsible)
      end
    end

    describe ".available?" do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  context "with an miq_databases row" do
    subject { NullEmbeddedAnsible.new }

    let(:miq_database) { MiqDatabase.first }

    before do
      FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
      MiqDatabase.seed
      EvmSpecHelper.create_guid_miq_server_zone
    end

    shared_context "api connection" do
      let(:api_conn) { double("AnsibleAPIConnection") }
      let(:api) { double("AnsibleAPIResource") }

      before do
        expect(subject).to receive(:api_connection).and_return(api_conn)
        expect(api_conn).to receive(:api).and_return(api)
      end
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
        include_context "api connection"

        before do
          expect(subject).to receive(:configured?).and_return true
          expect(subject).to receive(:running?).and_return true

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

    context "with a job cleanup template" do
      include_context "api connection"
      let(:data)          { double("ExtraData") }
      let(:schedule)      { double("Schedule", :save! => true, :extra_data => data) }
      let(:cleanup_jobs)  { double("SystemJobTemplate", :job_type => "cleanup_jobs", :schedules => [schedule]) }
      let(:cleanup_facts) { double("SystemJobTemplate", :job_type => "cleanup_facts") }

      before do
        expect(api).to receive(:system_job_templates).and_return(double("Enumerator", :all => [cleanup_jobs, cleanup_facts]))
      end

      describe "#set_job_data_retention" do
        it "sets the retention value in the schedule extra data" do
          stub_settings(:embedded_ansible => {:job_data_retention_days => 123})
          expect(data).to receive(:days=).with(123)
          subject.set_job_data_retention
        end
      end

      describe "#run_job_data_retention" do
        it "runs the cleanup job on demand with the passed value" do
          expect(cleanup_jobs).to receive(:launch).with("days" => 14)
          subject.run_job_data_retention(14)
        end

        it "defaults the days to the setting" do
          stub_settings(:embedded_ansible => {:job_data_retention_days => 1})
          expect(cleanup_jobs).to receive(:launch).with("days" => 1)
          subject.run_job_data_retention
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

    describe "#generate_password (private)" do
      it "doesn't include special characters" do
        100.times do
          pass = subject.send(:generate_password)
          expect(pass).to match(/^[a-zA-Z0-9]+$/)
        end
      end
    end
  end
end
