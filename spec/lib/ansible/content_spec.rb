RSpec.describe Ansible::Content do
  let(:content_dir)        { Pathname.new(Dir.mktmpdir) }
  let(:roles_dir)          { content_dir.join("roles") }
  let(:roles_requirements) { content_dir.join("roles", "requirements.yml") }

  subject { described_class.new(content_dir) }

  after { FileUtils.rm_rf(content_dir) }

  describe "#fetch_galaxy_roles" do
    it "doesn't run anything if there is no requirements file" do
      expect(AwesomeSpawn).not_to receive(:run!)

      subject.fetch_galaxy_roles
    end

    it "runs ansible-runner using the roles requirements file" do
      FileUtils.mkdir(roles_dir)
      FileUtils.touch(roles_requirements)

      expected_params = [
        "install",
        :roles_path= => roles_dir,
        :role_file=  => roles_requirements
      ]
      expect(AwesomeSpawn).to receive(:run!).with("ansible-galaxy", :params => expected_params)

      subject.fetch_galaxy_roles
    end

    it "works with a string path" do
      FileUtils.mkdir(roles_dir)
      FileUtils.touch(roles_requirements)

      expected_params = [
        "install",
        :roles_path= => roles_dir,
        :role_file=  => roles_requirements
      ]
      expect(AwesomeSpawn).to receive(:run!).with("ansible-galaxy", :params => expected_params)

      described_class.new(content_dir.to_s).fetch_galaxy_roles
    end
  end
end
