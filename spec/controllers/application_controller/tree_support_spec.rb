describe ApplicationController do
  context "#tree_autoload" do
    describe "verify @edit object" do
      before :each do
        expect(controller).to receive(:tree_add_child_nodes)
        expect(controller).to receive(:render)
        controller.instance_variable_set(:@sb,
                                         :trees       => {:foo_tree => {:active_node => "root"}},
                                         :active_tree => :foo_tree
                                        )
      end

      it "reloads from session" do
        edit = {:current => "test", :new => "test2"}
        session[:edit] = edit
        controller.tree_autoload
        expect(assigns(:edit)).to eq(edit)
      end

      it "stays nil" do
        controller.tree_autoload
        expect(assigns(:edit)).to be_nil
      end
    end
  end
end
