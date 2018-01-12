require 'docker'
require_dependency 'embedded_ansible'

describe ContainerEmbeddedAnsible do
  let(:miq_database) { MiqDatabase.first }
  let(:orchestrator) { double("ContainerOrchestrator") }

  before do
    allow(ContainerOrchestrator).to receive(:available?).and_return(true)
    allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
    allow(Docker).to receive(:validate_version!).and_raise(RuntimeError)
    allow(ContainerOrchestrator).to receive(:new).and_return(orchestrator)

    FactoryGirl.create(:miq_region, :region => ApplicationRecord.my_region_number)
    MiqDatabase.seed
    EvmSpecHelper.create_guid_miq_server_zone
  end

  describe "subject" do
    it "is an instance of ContainerEmbeddedAnsible" do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe ".available" do
    it "returns true" do
      expect(described_class.available?).to be true
    end
  end

  describe "#start" do
    it "waits for the service to respond" do
      expect(subject).to receive(:create_ansible_secret)
      expect(subject).to receive(:create_ansible_service)
      expect(subject).to receive(:create_ansible_deployment_config)

      expect(subject).to receive(:alive?).and_return(true)

      subject.start
    end
  end

  describe "#stop" do
    it "removes all the previously created objects" do
      expect(orchestrator).to receive(:delete_deployment_config).with("ansible")
      expect(orchestrator).to receive(:delete_service).with("ansible")
      expect(orchestrator).to receive(:delete_secret).with("ansible-secrets")

      subject.stop
    end
  end

  describe "#api_connection" do
    it "connects to the ansible service" do
      miq_database.set_ansible_admin_authentication(:password => "adminpassword")

      expect(AnsibleTowerClient::Connection).to receive(:new).with(
        :base_url   => "http://ansible/api/v1",
        :username   => "admin",
        :password   => "adminpassword",
        :verify_ssl => 0
      )

      subject.api_connection
    end
  end

  describe "#create_ansible_secret (private)" do
    it "uses the existing values in our database" do
      miq_database.ansible_secret_key = "secretkey"
      miq_database.set_ansible_rabbitmq_authentication(:password => "rabbitpass")
      miq_database.set_ansible_admin_authentication(:password => "12345")
      miq_database.set_ansible_database_authentication(:password => "dbpassword")

      expected_data = {
        "secret-key"        => "secretkey",
        "admin-password"    => "12345",
        "database-password" => "dbpassword",
        "rabbit-password"   => "rabbitpass"
      }
      expect(orchestrator).to receive(:create_secret).with("ansible-secrets", expected_data)
      subject.send(:create_ansible_secret)
    end
  end

  describe "#container_environment (private)" do
    let!(:db_user)     { miq_database.set_ansible_database_authentication(:password => "dbpassword").userid }
    let!(:rabbit_user) { miq_database.set_ansible_rabbitmq_authentication(:password => "rabbitpass").userid }

    around do |example|
      ENV["POSTGRESQL_SERVICE_HOST"] = "postgres.example.com"
      example.run
      ENV.delete("POSTGRESQL_SERVICE_HOST")
    end

    it "sends RABBITMQ_USER_NAME value from the database" do
      env_array = subject.send(:container_environment)
      env_entry = {:name => "RABBITMQ_USER_NAME", :value => rabbit_user}
      expect(env_array).to include(env_entry)
    end

    it "sends DATABASE_SERVICE_NAME value from the PG service host" do
      env_array = subject.send(:container_environment)
      env_entry = {:name => "DATABASE_SERVICE_NAME", :value => "postgres.example.com"}
      expect(env_array).to include(env_entry)
    end

    it "sends POSTGRESQL_USER value from the database" do
      env_array = subject.send(:container_environment)
      env_entry = {:name => "POSTGRESQL_USER", :value => db_user}
      expect(env_array).to include(env_entry)
    end
  end
end
