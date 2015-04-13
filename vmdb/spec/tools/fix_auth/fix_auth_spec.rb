require "spec_helper"

$LOAD_PATH << Rails.root.join("tools")

require "fix_auth/fix_auth"
require "fix_auth/models"

describe FixAuth::FixAuth do
  describe "#fix_database_yml" do
    it "supports --hardcode" do
      subject = described_class.new(:password => 'newpass', :root => '/', :databaseyml => true)
      expect(FixAuth::FixDatabaseYml).to receive(:run).with(:hardcode => 'newpass')
      subject.fix_database_yml
    end

    it "supports --password as an alias of --hardcode" do
      subject = described_class.new(:hardcode => 'newpass', :root => '/', :databaseyml => true)
      expect(FixAuth::FixDatabaseYml).to receive(:run).with(:hardcode => 'newpass')
      subject.fix_database_yml
    end
  end
end
