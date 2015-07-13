require "spec_helper"

describe AdvancedSearchesController do
  it "removes tokens if present" do
    exp = {'???' => '???'}
    edit = {:expression => {:val1 => {}, :val2 => {}, :expression => exp}, :edit_exp => exp}
    edit[:new] = {:expression => {:test => "foo", :token => 1}}
    session[:edit] = edit
    controller.instance_variable_set(:@_params, {:pressed => "discard"})
    controller.instance_variable_set(:@expkey, :expression)
    controller.should_receive(:render)
    controller.send(:exp_button)
    session[:edit][:expression].should_not include(:val1)
    session[:edit][:expression].should_not include(:val2)
    session[:edit].should_not include(:edit_exp)
    session[:edit][:expression][:expression].should == edit[:new][:expression]
  end
end
