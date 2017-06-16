require 'manageiq/active_record_connector'

describe ManageIQ::ActiveRecordConnector do
  def without_rails(rb_cmd)
    file = Rails.root.join("lib", "manageiq", "active_record_connector")
    `#{Gem.ruby} -e "require '#{file}'; #{rb_cmd}"`
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
      cmd_establish_connection   = "#{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")}, '#{logger.filename.to_s}')"
      cmd_connection_exists      = "puts #{described_class}.connection_exists?"
      # Not sure why this is a pain in the butt... but whatever...
      cmd_connection_logger_path = "puts ActiveRecord::Base.logger.instance_variable_get(:@logdev).filename"

      cmd = [
        cmd_establish_connection,
        cmd_connection_exists,
        cmd_connection_logger_path
      ]

      expected_output = "true\n#{logger.filename}"
      expect(without_rails(cmd.join("; ")).chomp).to eq(expected_output)
    end

    context "with a block passed" do
      let!(:vm) { FactoryGirl.create(:vm) }
      let(:query) do
        <<-TABLE_CHECK_QUERY.lines.map {|l| l.strip }.join(" ")
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
        cmd_establish_connection  = "#{described_class}.establish_connection_if_needed(#{config.inspect.gsub(/(")/, "\\\\\\1")}, '#{logger.filename.to_s}')"
        cmd_database_table_count  = %Q{ActiveRecord::Base.connection.select_value(\\"#{query}\\")}
        cmd_connection_block      = "puts #{cmd_establish_connection} { #{cmd_database_table_count} }"
        cmd_confirm_no_connection = "puts #{described_class}.connection_exists?"

        cmd = [
          cmd_connection_block,
          cmd_confirm_no_connection
        ]

        expected_output = "#{ActiveRecord::Base.connection.select_value(query)}\nfalse"
        expect(without_rails(cmd.join("; ")).chomp).to eq(expected_output)
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
