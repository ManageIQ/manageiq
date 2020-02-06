$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth/cli"

RSpec.describe FixAuth::Cli do
  describe "#parse" do
    it "should assign defaults" do
      opts = described_class.new.parse([], {})
             .options.slice(:hostname, :port, :username, :password, :hardcode, :database)
      expect(opts).to eq(
        :username => "root",
        :database => "vmdb_production",
        :port     => 5432)
    end

    it "should pickup env variables" do
      opts = described_class.new.parse([], "PGUSER" => "envuser", "PGPASSWORD" => "envpass", "PGHOST" => "envhost")
             .options.slice(:hostname, :username, :password, :hardcode, :database)
      expect(opts).to eq(
        :username => "envuser",
        :database => "vmdb_production",
        :password => "envpass",
        :hostname => "envhost")
    end

    it "should parse database names" do
      opts = described_class.new.parse(%w(DB1))
             .options.slice(:hostname, :username, :password, :hardcode, :database)
      expect(opts).to eq(
        :username => "root",
        :database => "DB1")
    end

    it "should parse hardcoded password" do
      opts = described_class.new.parse(%w(-P hardcoded))
             .options.slice(:hostname, :username, :password, :hardcode, :database)
      expect(opts).to eq(
        :username => "root",
        :database => "vmdb_production",
        :hardcode => "hardcoded")
    end

    it "defaults to updating the database" do
      opts = described_class.new.parse(%w())
             .options.slice(:db, :databaseyml, :key)
      expect(opts).to eq(:db => true)
    end

    it "doesnt default to database if running another task" do
      opts = described_class.new.parse(%w(--databaseyml))
             .options.slice(:db, :databaseyml, :key)
      expect(opts).to eq(:databaseyml => true)
    end

    it "doesnt default to database if running another task 2" do
      opts = described_class.new.parse(%w(--key))
             .options.slice(:db, :databaseyml, :key)
      expect(opts).to eq(:key => true)
    end

    it "can run all 3 tasks" do
      opts = described_class.new.parse(%w(--key --db --databaseyml))
             .options.slice(:db, :databaseyml, :key)
      expect(opts).to eq(:db => true, :databaseyml => true, :key => true)
    end

    it "parses legacy_keys" do
      opts = described_class.new.parse(%w(--legacy-key v2.bak))
             .options.slice(:legacy_key)
      expect(opts).to eq(:legacy_key => "v2.bak")
    end

    it "parses without legacy_keys specified" do
      opts = described_class.new.parse(%w())
             .options.slice(:legacy_key)
      expect(opts[:legacy_key]).not_to be
    end

    describe "v2" do
      it "exists" do
        expect { described_class.new.parse(%w(--v2)) }.not_to raise_error
      end
    end
  end
end
