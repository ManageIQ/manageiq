require "spec_helper"

$LOAD_PATH << Rails.root.join("tools")

require "fix_auth/cli"

describe FixAuth::Cli do
  it "should assign defaults" do
    options = described_class.new.parse([], {})
      .options.slice(:hostname, :username, :password, :hardcode, :databases)
    expect(options).to eq(
      :username  => "root",
      :databases => %w(vmdb_production))
  end

  it "should pickup env variables" do
    options = described_class.new.parse([], "PGUSER" => "envuser", "PGPASSWORD" => "envpass", "PGHOST" => "envhost")
      .options.slice(:hostname, :username, :password, :hardcode, :databases)
    expect(options).to eq(
      :username  => "envuser",
      :databases => %w(vmdb_production),
      :password  => "envpass",
      :hostname  => "envhost")
  end

  it "should parse database names" do
    options = described_class.new.parse(%w(DB1 DB2))
      .options.slice(:hostname, :username, :password, :hardcode, :databases)
    expect(options).to eq(
      :username  => "root",
      :databases => %w(DB1 DB2))
  end

  it "should parse hardcoded password" do
    options = described_class.new.parse(%w(-P hardcoded))
      .options.slice(:hostname, :username, :password, :hardcode, :databases)
    expect(options).to eq(
      :username  => "root",
      :databases => %w(vmdb_production),
      :hardcode  => "hardcoded")
  end
end
