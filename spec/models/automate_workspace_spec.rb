RSpec.describe AutomateWorkspace do
  describe "#merge_output!" do
    let(:aw) { FactoryBot.create(:automate_workspace, :input => input) }
    let(:password) { "ca$hc0w" }
    let(:encrypted) { ManageIQ::Password.encrypt(password) }
    let(:input) do
      { "objects"           => {
        "root" => {
          "var1" => "1",
          "var2" => "password::#{encrypted}",
          "var3" => "password::v2:{c8qTeiuz6JgbBOiDqp3eiQ==}"
        }
      },
        "method_parameters" => {"arg1" => "password::#{encrypted}"} }
    end

    it "raises error on invalid hash" do
      expect { aw.merge_output!({}) }.to raise_exception(ArgumentError)
    end

    it "properly merges the hash with the new output" do
      hash = {'objects' => {'root' => {'a' => 1}}, 'state_vars' => {'b' => 2}}
      partial_hash = {'objects' => {'root' => {'c' => 1}}, 'state_vars' => {} }
      merged_hash = {'objects' => {'root' => {'a' => 1, 'c' => 1}}, 'state_vars' => {'b' => 2}}

      aw.merge_output!(hash)
      aw.reload
      aw.merge_output!(partial_hash)
      aw.reload

      expect(aw.output).to eq(merged_hash)
    end

    it "#href_slug" do
      expect(aw.href_slug).to eq("automate_workspaces/#{aw.guid}")
    end

    it "#decrypt from object" do
      expect(aw.decrypt('root', 'var2')).to eq(password)
    end

    it "#decrypt from method parameters" do
      expect(aw.decrypt('method_parameters', 'arg1')).to eq(password)
    end

    it "#decrypt doesn't raise exception when bad encrypted data" do
      expect(aw.decrypt('root', 'var3')).to eq("")
    end

    it "#decrypt doesn't raise exception when object doesn't exist" do
      expect(aw.decrypt('frooti', 'var2')).to eq("")
    end

    it "#decrypt doesn't raise exception when attribute doesn't exist" do
      expect(aw.decrypt('root', 'nada')).to eq("")
    end

    it "#decrypt raises error when type is invalid" do
      expect(aw.decrypt('root', 'var1')).to eq("")
    end

    it "#encrypt" do
      aw.encrypt('root', 'mypassword', password)
      aw.reload
      expect(aw.output.fetch_path('objects', 'root', 'mypassword')).to eq("password::#{encrypted}")
    end
  end
end
