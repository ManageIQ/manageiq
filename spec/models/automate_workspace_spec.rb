describe AutomateWorkspace do
  describe "#merge_output!" do
    let(:user) { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:aw) do
      FactoryGirl.create(:automate_workspace, :user   => user,
                                              :tenant => user.current_tenant,
                                              :input  => input)
    end
    let(:password) { "secret" }
    let(:encrypted) { MiqAePassword.encrypt(password) }
    let(:input) do
      { 'objects'           => {'root' => { 'var1' => '1', 'var2' => "password::#{encrypted}"}},
        'method_parameters' => {'arg1' => "password::#{encrypted}"} }
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

    it "#decrypt raises error when object doesn't exist" do
      expect { aw.decrypt('frooti', 'var2') }.to raise_exception(ArgumentError)
    end

    it "#decrypt raises error when attribute doesn't exist" do
      expect { aw.decrypt('root', 'nada') }.to raise_exception(ArgumentError)
    end

    it "#decrypt raises error when type is invalid" do
      expect { aw.decrypt('root', 'var1') }.to raise_exception(ArgumentError)
    end

    it "#encrypt" do
      aw.encrypt('root', 'mypassword', password)
      aw.reload
      expect(aw.output.fetch_path('objects', 'root', 'mypassword')).to eq("password::#{encrypted}")
    end
  end
end
