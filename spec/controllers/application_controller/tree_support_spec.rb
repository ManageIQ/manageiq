require "spec_helper"
include UiConstants

describe ApplicationController do

  context "#tree_autoload_dynatree" do

    describe "verify @edit object" do
      before :each do
        controller.should_receive(:tree_add_child_nodes)
        controller.should_receive(:render)
        controller.instance_variable_set(:@sb,
                                         :trees       => {:foo_tree => {:active_node => "root"}},
                                         :active_tree => :foo_tree
        )
      end

      it "reloads from session" do
        edit = {:current => "test", :new => "test2"}
        session[:edit] = edit
        controller.tree_autoload_dynatree
        assigns(:edit).should == edit
      end

      it "stays nil" do
        controller.tree_autoload_dynatree
        assigns(:edit).should be_nil
      end
    end

  end
end
