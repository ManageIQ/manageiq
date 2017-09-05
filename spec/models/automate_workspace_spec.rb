describe AutomateWorkspace do
  context "#output=" do
    let(:user) { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:aw) { FactoryGirl.create(:automate_workspace, :user => user, :tenant => user.current_tenant) }
    it "raises error on invalid hash" do
      expect { aw.merge_output!({}) }.to raise_exception(ArgumentError)
    end

    it "properly merges the hash with the new output" do
      hash = {'workspace' => {'a' => 1}, 'state_vars' => {'b' => 2}}
      partial_hash = {'workspace' => {'c' => 1}}
      merged_hash = {'workspace' => {'a' => 1, 'c' => 1}, 'state_vars' => {'b' => 2}}

      aw.merge_output!(hash)
      aw.reload
      aw.merge_output!(partial_hash)
      aw.reload

      expect(aw.output).to eq(merged_hash)
    end
  end
end
