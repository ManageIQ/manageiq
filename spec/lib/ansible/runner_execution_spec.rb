RSpec.describe Ansible::Runner do
  before do
    skip("Ansible EE image not configured") unless described_class.available?
  end

  let(:data_directory) { Pathname.new(__dir__).join("runner/data") }

  it "runs a playbook" do
    response = Ansible::Runner.run_async({}, {}, data_directory.join("hello_world.yml").to_s).wait

    expect_ansible_runner_success(response)
    expect(response.human_stdout).to include('"msg": "Hello World!"')
  end

  it "runs a playbook with variables in a vars file" do
    response = Ansible::Runner.run_async({}, {}, data_directory.join("hello_world_vars_file.yml").to_s).wait

    expect_ansible_runner_success(response)
    expect(response.human_stdout).to include('"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"')
  end

  it "runs a playbook with vault encrypted variables" do
    credential = FactoryBot.create(:embedded_ansible_vault_credential, :password => "vault")

    response = Ansible::Runner.run_async({}, {}, data_directory.join("hello_world_vault_encrypted_vars.yml").to_s, :credentials => [credential.id]).wait

    expect_ansible_runner_success(response)
    expect(response.human_stdout).to include('"msg": "Hello World! (NOTE: This message has been encrypted with ansible-vault)"')
  end

  it "runs a playbook with variables in a vault encrypted vars file" do
    credential = FactoryBot.create(:embedded_ansible_vault_credential, :password => "vault")

    response = Ansible::Runner.run_async({}, {}, data_directory.join("hello_world_vault_encrypted_vars_file.yml").to_s, :credentials => [credential.id]).wait

    expect_ansible_runner_success(response)
    expect(response.human_stdout).to include('"msg": "Hello World! vars_file_1=vars_file_1_value, vars_file_2=vars_file_2_value"')
  end

  context "with a roles/requirements.yml" do
    it "installs roles via ansible-galaxy before running the playbook" do
      playbook = data_directory.join("hello_world_with_requirements/hello_world_with_requirements.yml")

      response = Ansible::Runner.run_async({}, {}, playbook.to_s).wait

      expect_ansible_runner_success(response)
      expect(response.human_stdout).to include("geerlingguy.ntp")
    end
  end

  it "runs a multi-play playbook and returns parsed events for plays and set_stats" do
    response = Ansible::Runner.run_async({}, {}, data_directory.join("multi_play_with_set_stats.yml").to_s).wait

    expect_ansible_runner_success(response)

    # JSON event parsing verification: plays are discovered via playbook_on_play_start events
    expect(response.plays.pluck("event_data").pluck("play")).to eq(["Play 1", "Play 2"])

    # JSON event parsing verification: set_stats artifact data is present in the final stats event
    expect(response.stats).to eq("custom_stat_var" => "stat_value")
  end

  def expect_ansible_runner_success(response, debug: false)
    stdout = "====== STDOUT ======\n#{response.human_stdout}"
    puts stdout if debug # rubocop:disable Rails/Output
    expect(response.return_code).to eq(0), "ansible-runner failed with:\n#{stdout}"
  end
end
