$LOAD_PATH << Rails.root.join("tools").to_s

require "fix_auth"
require "tempfile"
require "yaml"

RSpec.describe FixAuth::FixDatabaseYml do
  # TODO: add legacy password tests

  it "updates password" do
    with_databaseyml("oldpassword") do |databaseyml|
      FixAuth::FixDatabaseYml.file_name = databaseyml
      FixAuth::FixDatabaseYml.run(:hardcode => 'newpassword', :silent => true)

      expect(dbpassword(databaseyml)).to be_encrypted("newpassword")
    end
  end

  it "does not add a password" do
    with_databaseyml do |databaseyml|
      FixAuth::FixDatabaseYml.file_name = databaseyml
      FixAuth::FixDatabaseYml.run(:silent => true)
      expect(dbpassword(databaseyml)).to be_nil
    end
  end

  private

  # create a temporary databaseyml file to test
  def with_databaseyml(password = nil)
    temp = Tempfile.new(["database", ".yml"], Rails.root.join("tmp").to_s)
    temp.write(YAML.dump(settings(password)))
    temp.close

    yield temp.path
  ensure
    temp.delete
  end

  def dbpassword(filename)
    YAML.load_file(filename)["production"]["password"]
  end

  def settings(password)
    settings = {
      "username" => "root",
      "host"     => "server.example.com"
    }
    settings["password"] = password if password
    {"production" => settings}
  end
end
