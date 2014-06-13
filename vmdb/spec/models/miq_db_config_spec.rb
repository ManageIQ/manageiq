require "spec_helper"

describe MiqDbConfig do

  it ".log_activity_statistics" do
    activity_stats  = [{"session_id" => 79687, "blocked_by" => nil, "wait_time_ms" => 0}]
    expected_output = "MIQ(DbConfig.log_activity_statistics) <<-ACTIVITY_STATS_CSV\nsession_id,blocked_by,wait_time_ms\n79687,,0\nACTIVITY_STATS_CSV"
    ActiveRecord::Base.stub_chain(:connection, :activity_stats).and_return(activity_stats)
    $log ||= double
    $log.should_receive(:info).with(expected_output)

    MiqDbConfig.log_activity_statistics
  end

  it ".get_db_types" do
    expected = {
      "internal"     => "Internal Database on this CFME Appliance",
      "external_evm" => "External Database on another CFME Appliance",
      "postgresql"   => "External Postgres Database"
    }

    MiqDbConfig.get_db_types.should == expected
  end

  context ".raw_config" do
    let(:password) { "pa$$word" }
    let(:enc_pass) { MiqPassword.encrypt(password) }

    before do
      yaml = <<-EOF
---
production:
  host: localhost
  username: root
  password: <%= MiqPassword.decrypt(\"#{enc_pass}\")%>
EOF
      IO.stub(:read => yaml)
    end

    it "production" do
      Rails.stub(:env => ActiveSupport::StringInquirer.new("production"))
      ERB.should_not_receive(:new)

      expected = {"host" => "localhost", "username" => "root", "password" => "<%= MiqPassword.decrypt(\"#{enc_pass}\")%>"}
      MiqDbConfig.raw_config["production"].should == expected
    end

    it "non-production" do
      ERB.should_receive(:new).and_call_original

      expected = {"host" => "localhost", "username" => "root", "password" => password}
      MiqDbConfig.raw_config["production"].should == expected
    end
  end

  context ".current" do
    before do
      @db_config = {
        :production => {
          :adapter  => "postgresql",
          :host     => "localhost",
          :database => "vmdb_production",
          :username => "user",
          :password => "password"
        }
      }
      described_class.stub(:database_configuration => @db_config)
    end
    subject { described_class.current }

    it "internal" do
      expect(subject.options).to eq(
        :name     => "internal",
        :adapter  => "postgresql",
        :host     => "localhost",
        :database => "vmdb_production",
        :username => "user",
        :password => "password"
      )
    end

    it "internal for loopback" do
      @db_config.store_path(:production, :host, "127.0.0.1")
      expect(subject.options).to eq(
        :name     => "internal",
        :adapter  => "postgresql",
        :host     => "127.0.0.1",
        :database => "vmdb_production",
        :username => "user",
        :password => "password"
      )
    end

    it "internal for empty host" do
      @db_config[:production].delete(:host)
      expect(subject.options).to eq(
        :name     => "internal",
        :adapter  => "postgresql",
#        :host=>"",
        :database => "vmdb_production",
        :username => "user",
        :password => "password"
      )
    end

    it "external evm" do
      @db_config.store_path(:production, :host, "192.168.0.23")
      expect(subject.options).to eq(
        :name     => "external_evm",
        :adapter  => "postgresql",
        :host     => "192.168.0.23",
        :database => "vmdb_production",
        :username => "user",
        :password => "password"
      )
    end

    it "external postgresql" do
      @db_config.store_path(:production, :host, "192.168.0.23")
      @db_config.store_path(:production, :database, "prod1")
      expect(subject.options).to eq(
        :name     => "postgresql",
        :adapter  => "postgresql",
        :host     => "192.168.0.23",
        :database => "prod1",
        :username => "user",
        :password => "password")
    end
  end

  context ".current external" do
    before do
      @db_config = {
        :production => {
          :adapter  => "postgresql",
          :host     => "192.168.0.23",
          :database => "prod1",
          :username => "user",
          :password => "password"
        }
      }
      described_class.stub(:database_configuration => @db_config)
    end
    subject { described_class.current }

    it "external postgresql" do
      expect(subject.options).to eq(
        :name     => "postgresql",
        :adapter  => "postgresql",
        :host     => "192.168.0.23",
        :database => "prod1",
        :username => "user",
        :password => "password")
    end
  end

  context "#save_internal" do
    subject { described_class.new(:name => "internal").save_internal }

    it "returns saved VMDB::Config" do
      described_class.should_receive(:backup_file).any_number_of_times
      VMDB::Config.any_instance.should_receive(:save_file)
      expect(subject.config.fetch_path(:production, :host)).to be_nil
    end

    it "resets cache" do
      described_class.should_receive(:backup_file).any_number_of_times
      VMDB::Config.any_instance.should_receive(:save_file)
      subject
      expect(described_class.raw_config.fetch_path('production')).to eq(
        "adapter"      => "postgresql",
        "database"     => "vmdb_production",
        "username"     => "root",
        "encoding"     => "utf8",
        "pool"         => 5,
        "wait_timeout" => 5
      )
    end

    context "with password" do
      subject { described_class.new(:name => "internal", :host => 'localhost', :password => "x").save_internal }

      it "should save password to database.yml" do
        described_class.should_receive(:backup_file).any_number_of_times
        VMDB::Config.any_instance.should_receive(:save_file)
        subject
        expect(described_class.raw_config.fetch_path('production')).to eq(
          "adapter"      => "postgresql",
          "host"         => "localhost",
          "database"     => "vmdb_production",
          "username"     => "root",
          "password"     => "x",
          "encoding"     => "utf8",
          "pool"         => 5,
          "wait_timeout" => 5
        )
      end
    end
  end

  context "#save_common" do
    before do
      described_class.should_receive(:backup_file)
      VMDB::Config.any_instance.should_receive(:save_file)

      config = described_class.new({:name => "external_evm", :host => "abc"})
      @vmdb_config = config.save_common
    end

    it "returns saved VMDB::Config" do
      @vmdb_config.config.fetch_path(:production, :host).should == "abc"
    end

    it "resets cache" do
      described_class.raw_config.fetch_path('production', 'host').should == "abc"
    end
  end
end
