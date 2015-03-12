require "spec_helper"
include UiConstants

describe ApplicationController do
  class FakeController < Struct.new :session, :params
    include ApplicationController::Filter

    attr_accessor :expkey
    attr_accessor :edit

    def render(type)
    end
  end

  before :each do
    controller.instance_variable_set(:@sb, {})
  end

  context "exp_changed" do
    context "field type didn't change" do
      attr_reader :controller

      before(:each) do
        @controller = FakeController.new
        @controller.expkey = :expression
        @controller.params = {}
        @controller.session = {
          :edit => { controller.expkey => { } }
        }
      end

      def set_chosen_typ(type)
        set_expkey_value :exp_typ, type
        set_param_value :exp_typ, type
      end

      def set_expkey_value(key, value)
        controller.session[:edit][controller.expkey][key] = value
      end

      def get_expkey_value(key)
        controller.session[:edit][controller.expkey][key]
      end

      def set_param_value(key, value)
        controller.params[key] = value
      end

      def set_edit_value(key, value)
        controller.session[:edit][key] = value
      end

      def get_edit_value(key)
        controller.session[:edit][key]
      end
      
      context "exp_typ is field" do
        before(:each) do
          set_chosen_typ "field"
        end

        it "detects changed exp_field with <Choose>" do
          set_expkey_value :exp_field, "foo"
          set_param_value :chosen_field, "<Choose>"
          controller.exp_changed
          expect(controller.edit).to eq({:expression => {:exp_typ   => "field",
                                                         :exp_field => nil,
                                                         :exp_value => nil,
                                                         :exp_key   => nil,
                                                         :alias     => nil},
                                         :suffix     => nil})
        end

        it "detects chosen key changes and deletes suffix" do
          set_param_value :chosen_key, "RUBY"
          set_expkey_value :exp_key, "hello"
          set_edit_value :suffix, Object.new
          controller.exp_changed

          expect(get_edit_value(:suffix)).to be_nil
          expect(get_expkey_value(:exp_key)).to eq("RUBY")
        end

        context "changed exp_field with non-<Choose> chosen field" do
          before(:each) do
            set_expkey_value :exp_field, "foo"
            set_param_value :chosen_field, "something"
          end

          it "detects changes when :chosen_field is a truthy value" do
            controller.exp_changed
            expect(controller.edit).to eq({:expression => {:exp_typ   => "field",
                                                           :exp_field => "something",
                                                           :exp_value => nil,
                                                           :exp_key   => "=",
                                                           :val1      => {:type  => :string,
                                                                          :title => "Enter a Text String"},
                                                           :val2      => {:type=>nil},
                                                           :alias     => nil},

                                           :suffix    => nil})
          end

          it "exp_model is not _display_filter_ and exp_field is plural" do
            set_param_value :chosen_field, "User.miq_widgets"
            set_expkey_value :exp_model, "foo"
            controller.exp_changed
            expect(controller.edit).to eq({:expression => {:exp_typ   => "field",
                                                           :exp_field => "User.miq_widgets",
                                                           :exp_model => "foo",
                                                           :exp_value => nil,
                                                           :exp_key   => "CONTAINS",
                                                           :val1      => {:type  => :string,
                                                                          :title => "Enter a Text String"},
                                                           :val2      => {:type=>nil},
                                                           :alias     => nil},
                                           :suffix     => nil})
          end

          it "leaves exp_key alone" do
            set_expkey_value :exp_field, "string"
            set_expkey_value :exp_key, "STARTS WITH"
            controller.exp_changed
            expect(controller.edit).to eq({:expression => {:exp_typ   => "field",
                                                           :exp_field => "something",
                                                           :exp_value => nil,
                                                           :exp_key   => "STARTS WITH",
                                                           :val1      => {:type  => :string,
                                                                          :title => "Enter a Text String"},
                                                           :val2      => {:type=>nil},
                                                           :alias     => nil},

                                           :suffix    => nil})
          end
        end
      end
    end

    context "field type changed" do
      attr_reader :controller

      before(:each) do
        @controller = FakeController.new
        @controller.expkey = :expression
        @controller.session = {
          :edit => { @controller.expkey => { :exp_typ => :foo } }
        }
      end

      def set_chosen_typ(type)
        controller.params = { :chosen_typ => type }
      end

      it "sets up exp vals" do
        set_chosen_typ :bar
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => :bar,
                                                             :exp_key    => nil,
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil},
                                       :suffix2          => nil,
                                       :suffix           => nil})
      end

      it "sets up exp_typ for <Choose>" do
        set_chosen_typ "<Choose>"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => nil,
                                                             :exp_key    => nil,
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil},
                                        :suffix2         => nil,
                                        :suffix          => nil})
      end

      it "sets up exp_field for field" do
        set_chosen_typ "field"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => "field",
                                                             :exp_key    => nil,
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_field  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil},
                                        :suffix2         => nil,
                                        :suffix          =>nil})
      end

      it "sets up exp_key for count" do
        set_chosen_typ "count"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ       => "count",
                                                             :exp_key       => "=",
                                                             :alias         => nil,
                                                             :exp_skey      => nil,
                                                             :exp_ckey      => nil,
                                                             :exp_value     => nil,
                                                             :exp_cvalue    => nil,
                                                             :exp_regkey    => nil,
                                                             :exp_regval    => nil,
                                                             :exp_count     => nil,
                                                             :val1          => {:type  => :integer,
                                                                                :title => "Enter an Integer"},
                                                             :val2          => {:type => nil}},
                                       :suffix2          => nil,
                                       :suffix           => nil})
      end

      it "sets up exp_key for tag" do
        set_chosen_typ "tag"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => "tag",
                                                             :exp_key    => "CONTAINS",
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil,
                                                             :exp_tag    => nil},
                                       :suffix2       => nil,
                                       :suffix        => nil})
      end

      it "sets up exp_key for regkey" do
        set_chosen_typ "regkey"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => "regkey",
                                                             :exp_key    => "=",
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil,
                                                             :val1       => {:type  => :string,
                                                                             :title => "Enter a Text String"},
                                                             :val2       => {:type => nil}},
                                       :suffix2          => nil,
                                       :suffix           => nil})
      end

      it "sets up exp_key for find" do
        set_chosen_typ "find"
        controller.exp_changed
        expect(controller.edit).to eq({controller.expkey => {:exp_typ    => "find",
                                                             :exp_key    => "FIND",
                                                             :alias      => nil,
                                                             :exp_skey   => nil,
                                                             :exp_ckey   => nil,
                                                             :exp_value  => nil,
                                                             :exp_cvalue => nil,
                                                             :exp_regkey => nil,
                                                             :exp_regval => nil,
                                                             :exp_field  => nil,
                                                             :exp_check  => "checkall",
                                                             :exp_cfield => nil},
                                                             :suffix2    => nil,
                                                             :suffix     => nil})
      end
    end
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
      e = MiqExpression.new({"=" => {:field => "Vm.name", :value => "Test"}})
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
end
