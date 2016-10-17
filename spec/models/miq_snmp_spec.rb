describe MiqSnmp do
  describe '.trap_v2' do
    it 'calls subst_oid' do
      expect(MiqSnmp).to receive(:subst_oid).at_least(1).and_return("1.2.3")

      MiqSnmp.trap_v2(:host        => ["localhost"],
                      :sysuptime   => 1,
                      :trap_oid    => "info",
                      :object_list => [{:oid => "1.2.3", :var_type => "Integer", :value => "1"}])
    end
  end
end
