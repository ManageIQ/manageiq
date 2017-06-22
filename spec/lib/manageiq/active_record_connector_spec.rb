require 'manageiq/active_record_connector'

describe ManageIQ::ActiveRecordConnector do
  def without_rails(rb_cmd, env = nil)
    file    = Rails.root.join("lib", "manageiq", "active_record_connector")
    env_out = env.map { |k, v| "#{k}=#{v}" }.join(" ") if env && env.kind_of?(Hash)
    `#{env_out} #{Gem.ruby} -e "require '#{file}'; #{rb_cmd}"`.chomp
  end

  describe ".connection_exists" do
    it "returns true when a connection is already established" do
      expect(described_class.connection_exists?).to be true
    end

    it "returns false when a connection does already not exist" do
      cmd = "print #{described_class}.connection_exists?"
      expect(without_rails(cmd)).to eq("false")
    end
  end

  describe ".establish_connection_if_needed" do
    # Save off existing setup
    let!(:config)     { ActiveRecord::Base.connection_config }
    let!(:connection) { ActiveRecord::Base.connection }
    let!(:logger)     { ActiveRecord::Base.logger }

    it "doesn't create a new connection/logger if it doesn't need to" do
      described_class.establish_connection_if_needed(config, logger.filename)

      expect(ActiveRecord::Base.connection).to eq(connection)
      expect(ActiveRecord::Base.logger).to     eq(logger)
    end

    it "creates a new connection as needed" do
      cmd = [
        "#{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")}, '#{logger.filename}')",
        "puts #{described_class}.connection_exists?",
        # We aren't using vmdb-logger in the without_rails section of the code,
        # so the `filename` and `logdev` methods aren't available like they
        # are in VmdbLogger, which is what our logger is for rails.  Have to
        # do it this way in the script because of that.
        "puts ActiveRecord::Base.logger.instance_variable_get(:@logdev).filename"
      ].join("; ")

      expected_output = "true\n#{logger.filename}"
      expect(without_rails(cmd)).to eq(expected_output)
    end

    it "uses a default logger if a log path isn't supplied" do
      cmd = [
        "#{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")})",
        "puts #{described_class}.connection_exists?",
        "puts ActiveRecord::Base.logger.instance_variable_get(:@logdev).filename"
      ].join("; ")

      expected_output = "true\n#{ManageIQ.root.join "log", "test.log"}"
      expect(without_rails(cmd)).to eq(expected_output)
    end

    it "reuses the existing logger if that is already set" do
      cmd = [
        "ActiveRecord::Base.logger = Logger.new '#{ManageIQ.root.join "log", "foobar.log"}'",
        "#{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")})",
        "puts #{described_class}.connection_exists?",
        "puts ActiveRecord::Base.logger.instance_variable_get(:@logdev).filename"
      ].join("; ")

      expected_output = "true\n#{ManageIQ.root.join "log", "foobar.log"}"
      expect(without_rails(cmd)).to eq(expected_output)
    end

    it "favors DATABASE_URL over database.yml" do
      env = {"DATABASE_URL" => "postgres://root@localhost:12345/test"}
      cmd = [
        "ActiveRecord::Base.logger = Logger.new '#{ManageIQ.root.join "log", "foobar.log"}'",
        "config = #{described_class}::ConnectionConfig.database_configuration",
        "#{described_class}.establish_connection_if_needed(config)",
        "puts ActiveRecord::Base.connection_config.to_json"
      ].join("; ")

      expected_config = config.stringify_keys.merge(
        "adapter"  => "postgresql",
        "username" => "root",
        "host"     => "localhost",
        "port"     => 12_345,
        "database" => "test"
      )

      result = without_rails(cmd, env)
      expect(JSON.parse(result)).to eq(expected_config)
    end

    it "defaults to dev environment properly if Rails.env is not available" do
      env = {
        "RAILS_ENV" => nil,
        "RACK_ENV"  => nil
      }
      cmd = [
        "ActiveRecord::Base.logger = Logger.new '#{ManageIQ.root.join "log", "foobar.log"}'",
        "config = #{described_class}::ConnectionConfig.database_configuration",
        "#{described_class}.establish_connection_if_needed(config)",
        "puts ActiveRecord::Base.connection_config.to_json"
      ].join("; ")

      expected_config = ActiveRecord::Base.configurations["development"]
      result = without_rails(cmd, env)
      expect(JSON.parse(result)).to eq(expected_config)
    end

    context "with a block passed" do
      let!(:vm) { FactoryGirl.create(:vm) }
      let(:query) do
        <<-TABLE_CHECK_QUERY.lines.map(&:strip).join(" ")
          SELECT COUNT(table_name)
            FROM information_schema.tables
           WHERE table_schema=\'public\'
             AND table_type='BASE TABLE';
        TABLE_CHECK_QUERY
      end

      it "runs the block and returns it's value" do
        expected_id = described_class.establish_connection_if_needed(config, logger.filename) do
          # Do the same things as we do in the next test for consistency
          ActiveRecord::Base.connection.select_value("SELECT id FROM vms ORDER BY id DESC LIMIT 1")
        end

        expect(expected_id).to eq(vm.id)
      end

      # NOTE:  Because of transactional fixtures, it is impossible to use the
      # `let!` block to test the connection having data in the DB as it doesn't
      # really persist in the database.
      #
      # Time wasted figuring this out:  ~2hr
      #
      # Instead, we are just counting the database tables that exist
      it "creates and closes a connection if needed" do
        cmd = [
          "result = #{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")}, '#{logger.filename}') do",
          "  ActiveRecord::Base.connection.select_value(\\\"#{query}\\\")",
          "end",
          "puts result",
          "puts #{described_class}.connection_exists?"
        ].join("; ")

        expected_output = "#{ActiveRecord::Base.connection.select_value(query)}\nfalse"
        expect(without_rails(cmd)).to eq(expected_output)
      end
    end

    describe "ConnectionConfig" do
      describe ".database_configuration" do
        it "finds the same config as would be by Rails" do
          expected = ActiveRecord::Base.connection_config.stringify_keys
          expect(described_class::ConnectionConfig.database_configuration[Rails.env]).to eq(expected)
        end
      end

      describe ".[]" do
        it "is a shorthand for database_configuration[env]" do
          expected = ActiveRecord::Base.connection_config.stringify_keys
          expect(described_class::ConnectionConfig[Rails.env]).to eq(expected)
        end
      end
    end
  end
end
