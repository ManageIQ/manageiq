require "spec_helper"
include UiConstants

describe ApplicationController, "::Filter" do
  before :each do
    controller.instance_variable_set(:@sb, {})
  end

  context "Verify removal of tokens from expressions" do
    it "removes tokens if present" do
      e = MiqExpression.new({"=" => {:field => "Vm.name", :value => "Test"}, :token => 1})
      exp = e.exp
      controller.send(:exp_remove_tokens, exp)
      exp.inspect.include?(":token").should be_false
    end

    it "removes tokens if present in complex expression" do
      e = MiqExpression.new("or" => [{"=" => {:field => "Vm.name", :value => "Test"}, :token => 1},
                                     {"=" => {:field => "Vm.name", :value => "Test2"}, :token => 2}])
      exp = e.exp
      controller.send(:exp_remove_tokens, exp)
      exp.inspect.include?(":token").should be_false
    end

    it "leaves expression untouched if no tokens present" do
      e = MiqExpression.new("=" => {:field => "Vm.name", :value => "Test"})
      exp = e.exp
      exp2 = copy_hash(exp)
      controller.send(:exp_remove_tokens, exp2)
      exp.inspect.should == exp2.inspect
    end

    it "removes tokens if present" do
      exp = {'???' => '???'}
      edit = {:expression => {:val1 => {}, :val2 => {}, :expression => exp}, :edit_exp => exp}
      edit[:new] = {:expression => {:test => "foo", :token => 1}}
      session[:edit] = edit
      controller.instance_variable_set(:@_params, :pressed => "discard")
      controller.instance_variable_set(:@expkey, :expression)
      controller.should_receive(:render)
      controller.send(:exp_button)
      session[:edit][:expression].should_not include(:val1)
      session[:edit][:expression].should_not include(:val2)
      session[:edit].should_not include(:edit_exp)
      session[:edit][:expression][:expression].should == edit[:new][:expression]
    end
  end

  describe "#save_default_search" do
    let(:user) { FactoryGirl.create(:user_with_group, :settings => {:default_search => {}}) }
    it "saves settings" do
      search = FactoryGirl.create(:miq_search, :name => 'sds')

      login_as user
      controller.instance_variable_set(:@settings, {})
      controller.instance_variable_set(:@_response, double.as_null_object)
      controller.instance_variable_set(:@_params, :id => search.id)
      session[:view] = controller.send(:get_db_view, Host)

      controller.send(:save_default_search)
      user.reload

      expect(user.settings).to eq(:default_search => {:Host => search.id})
    end
  end

  describe "#adv_search_build_lists (private)" do
    let(:user)           { FactoryGirl.create(:user) }
    let(:user_search)    { FactoryGirl.create(:miq_search_user, :search_key => user.userid) }
    let(:user_search2)   { FactoryGirl.create(:miq_search_user, :search_key => user.userid) }
    let(:global_search)  { FactoryGirl.create(:miq_search_global) }
    let(:global_search2) { FactoryGirl.create(:miq_search_global) }

    before do
      user_search  # Create the searches
      user_search2

      session[:userid] = user.userid
      controller.instance_variable_set(:@expkey, :expression)
      controller.instance_variable_set(:@edit, :expression => {:exp_model => "Vm"})
    end

    it "with global searches" do
      global_search  # Create the searches
      global_search2

      controller.send(:adv_search_build_lists)
      actual = controller.instance_variable_get(:@edit)[:expression][:exp_search_expressions]

      expect(actual).to eq [  # eq asserts that the output is sorted
        ["Global - #{global_search.description}",  global_search.id],
        ["Global - #{global_search2.description}", global_search2.id],
        [user_search.description,                  user_search.id],
        [user_search2.description,                 user_search2.id]
      ]
    end

    it "without global searches" do
      controller.send(:adv_search_build_lists)
      actual = controller.instance_variable_get(:@edit)[:expression][:exp_search_expressions]

      expect(actual).to eq [  # eq asserts that the output is sorted
        [user_search.description,  user_search.id],
        [user_search2.description, user_search2.id]
      ]
    end

    it "does not include searches from other users" do
      FactoryGirl.create(:miq_search_user, :search_key => -1) # A search from another "user"

      controller.send(:adv_search_build_lists)
      actual = controller.instance_variable_get(:@edit)[:expression][:exp_search_expressions]

      expect(actual).to eq [  # eq asserts that the output is sorted
        [user_search.description,  user_search.id],
        [user_search2.description, user_search2.id]
      ]
    end
  end
end
