describe MiqDbConfig do
  CSV_HEADER = %w( session_id
                   xact_start
                   last_request_start_time
                   command
                   task_state
                   login
                   application
                   request_id
                   net_address
                   host_name
                   client_port
                   wait_time_ms
                   blocked_by )

  context ".log_activity_statistics" do
    before do
      @buffer = StringIO.new
      class << @buffer
        alias_method :info, :write
        alias_method :warn, :write
      end
    end

    it "normal" do
      MiqDbConfig.log_activity_statistics(@buffer)
      lines = @buffer.string.lines
      expect(lines.shift).to eq "MIQ(DbConfig.log_activity_statistics) <<-ACTIVITY_STATS_CSV\n"
      expect(lines.pop).to eq "ACTIVITY_STATS_CSV"

      header, *rows = CSV.parse lines.join
      expect(header).to eq(CSV_HEADER)

      expect(rows.length).to be > 0
      rows.each do |row|
        expect(row.first).to be_truthy
      end
    end

    it "exception" do
      allow(VmdbDatabaseConnection).to receive(:all).and_raise("FAILURE")
      MiqDbConfig.log_activity_statistics(@buffer)
      expect(@buffer.string.lines.first).to eq("MIQ(DbConfig.log_activity_statistics) Unable to log stats, 'FAILURE'")
    end
  end

  it ".get_db_types" do
    expected = {
      "internal"     => "Internal Database on this CFME Appliance",
      "external_evm" => "External Database on another CFME Appliance",
      "postgresql"   => "External Postgres Database"
    }

    expect(MiqDbConfig.get_db_types).to eq(expected)
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
      allow(described_class).to receive_messages(:database_configuration => @db_config)
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
      allow(described_class).to receive_messages(:database_configuration => @db_config)
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
      allow(described_class).to receive(:backup_file)
      expect_any_instance_of(VMDB::Config).to receive(:save_file)
      expect(subject.config.fetch_path(:production, :host)).to be_nil
    end

    it "resets cache" do
      allow(described_class).to receive(:backup_file)
      expect_any_instance_of(VMDB::Config).to receive(:save_file)
      subject
      expect(described_class.database_configuration[:production]).to eq(
        :adapter      => "postgresql",
        :database     => "vmdb_production",
        :username     => "root",
        :encoding     => "utf8",
        :pool         => 5,
        :wait_timeout => 5
      )
    end

    context "with password" do
      subject { described_class.new(:name => "internal", :host => 'localhost', :password => "x").save_internal }

      it "should save password to database.yml" do
        allow(described_class).to receive(:backup_file)
        expect_any_instance_of(VMDB::Config).to receive(:save_file)
        subject
        expect(described_class.database_configuration[:production]).to eq(
          :adapter      => "postgresql",
          :host         => "localhost",
          :database     => "vmdb_production",
          :username     => "root",
          :password     => "x",
          :encoding     => "utf8",
          :pool         => 5,
          :wait_timeout => 5
        )
      end
    end
  end

  context "#save_common" do
    before do
      expect(described_class).to receive(:backup_file)
      expect_any_instance_of(VMDB::Config).to receive(:save_file)

      config = described_class.new({:name => "external_evm", :host => "abc"})
      @vmdb_config = config.save_common
    end

    it "returns saved VMDB::Config" do
      expect(@vmdb_config.config.fetch_path(:production, :host)).to eq("abc")
    end

    it "resets cache" do
      expect(described_class.database_configuration.fetch_path(:production, :host)).to eq("abc")
    end
  end

  context "#verify_config" do
    let(:current) { described_class.new(ActiveRecord::Base.connection_pool.spec.config.merge(:name => "internal")) }

    it "not from_save, checks connectivity only by default" do
      current.options[:database] = "non_existing_database"
      expect(current.verify_config).to eq false
    end

    it "restores ActiveRecord::Base configuration after" do
      before = ActiveRecord::Base.connection.current_database
      current.options[:database] = "non_existing_database"
      current.verify_config

      expect(ActiveRecord::Base.connection.current_database).to eq before
    end

    it "from_save, is true at latest schema" do
      expect(current.verify_config(true)).to eq true
    end

    it "from_save, is false and captures any error messages" do
      current.options[:database] = "non_existing_database"
      expect(current.verify_config(true)).to eq false

      error = current.errors.first
      expect(error[0]).to eq :configuration
      expect(error[1]).to match(/non_existing_database.+does not exist/)
    end
  end
end
