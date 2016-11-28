describe ReportController do
  describe "#edit_folder" do
    before(:each) do
      controller.instance_variable_set(:@grid_folders, nil)
      session[:node_selected] = 'foo__bar'
      controller.instance_variable_set(:@edit, {:new => [['bar', ['baz', 'quux']],  # match
                                                         ['foo', ['frob']]],        # no match
                                                :group_reports => []})
    end

    it "sets @folders to be of proper length" do
      controller.send(:edit_folder)
      expect(controller.instance_variable_get(:@folders).length).to eq(2)
    end

    it "sets @grid_folders" do
      expect(controller).to receive(:menu_folders).and_return({})
      controller.send(:edit_folder)
      expect(controller.instance_variable_get(:@grid_folders)).to_not be_nil
    end
  end

  describe "#menu_folders" do
    it "can handle nil" do
      controller.instance_variable_set(:@edit, {:user_typ => true})
      out = controller.send(:menu_folders, [nil, 'foo'])

      expect(out.size).to eq(1)
      expect(out.first[:text]).to eq('foo')
    end

    it "prepends i_ to id for admins" do
      controller.instance_variable_set(:@edit, {:user_typ => true})
      arr = %w(foo bar)
      out = controller.send(:menu_folders, arr)

      expect(out).to eq(arr.map do |s|
        {:id => "i_#{s}", :text => s}
      end)
    end

    it "prepends __|i_ when no reports" do
      controller.instance_variable_set(:@edit, {:group_reports => []})
      arr = %w(foo bar)
      out = controller.send(:menu_folders, arr)

      expect(out).to eq(arr.map do |s|
        {:id => "__|i_#{s}", :text => s}
      end)
    end

    it "handles reports for b__" do
      session[:node_selected] = 'b__*'
      controller.instance_variable_set(:@edit, {:group_reports => ['A/*']})
      out = controller.send(:menu_folders, %w(A B))

      expect(out).to eq([{:id => "i_A", :text => "A"},
                         {:id => "|-|i_B", :text => "B"}])
    end

    it "handles reports for non-b__" do
      session[:node_selected] = '*__*'
      controller.instance_variable_set(:@edit, {:group_reports => ['*/A']})
      out = controller.send(:menu_folders, %w(A B))

      expect(out).to eq([{:id => "i_A", :text => "A"},
                         {:id => "|-|i_B", :text => "B"}])
    end
  end
end
