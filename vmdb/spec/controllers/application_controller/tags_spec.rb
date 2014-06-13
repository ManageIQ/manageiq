require "spec_helper"

describe ApplicationController  do
  describe "#get_tagdata" do
    let(:record) { Host.new; instance_double("Host") }

    before do
      session[:userid] = "testuser"
      record.stub(:tagged_with).with(:cat => "testuser").and_return("my tags")
      Classification.stub(:find_assigned_entries).with(record).and_return(classifications)
    end

    context "when classifications exist" do
      let(:parent) { double("Parent", :description => "Department") }
      let(:child1) { double("Child1", :parent => parent, :description => "Automotive") }
      let(:child2) { double("Child2", :parent => parent, :description => "Financial Services") }
      let(:classifications) { [child1, child2] }

      it "populates the assigned filters in the session" do
        controller.send(:get_tagdata, record)
        session[:assigned_filters]['Department'].should == ["Automotive", "Financial Services"]
        session[:mytags].should == "my tags"
      end
    end

    context "when classifications do not exist" do
      let(:classifications) { [] }

      it "sets the assigned filters to an empty hash in the session" do
        controller.send(:get_tagdata, record)
        session[:assigned_filters].should == {}
        session[:mytags].should == "my tags"
      end
    end
  end
end
