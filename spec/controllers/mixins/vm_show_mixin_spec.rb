class FakeController
  include VmShowMixin

  attr_writer :edit
  attr_accessor :session
end

describe VmShowMixin do
  subject { FakeController.new }
  let(:edit)         { nil }
  let(:my_session)   { {} }
  let(:miq_exp_col)  { "Vm-name" }
  let(:simple_exp)   { {"=" => {"field" => miq_exp_col, "value" => "foo"}} }
  let(:exp)          { {:adv_search_applied => {:exp => simple_exp}} }
  let(:qs_exp)       { {:adv_search_applied => {:qs_exp => simple_exp}} }
  let(:empty_search) { {:adv_search_applied => {:exp => {}}} }

  before do
    subject.edit = edit
    subject.session = my_session
  end

  describe "set_named_scope" do
    let(:edit)        { exp }
    let(:named_scope) { subject.instance_variable_get(:@named_scope) }

    it "sets @named_scope to nil by default" do
      subject.send(:set_named_scope)
      expect(named_scope).to eq(nil)
    end

    context "when miq_search_exp_fields includes other fields" do
      let(:exp1) { {"=" => {"field" => "Vm-name"}} }
      let(:exp2) { {"=" => {"field" => "Vm-description"}} }
      let(:simple_exp) { [exp1, exp2] }

      it "sets @named_scope to nil" do
        subject.send(:set_named_scope)
        expect(named_scope).to eq(nil)
      end
    end

    context "when miq_search_exp_fields includes owned_by_current_ldap_group" do
      let(:simple_exp) { {"=" => {"field" => "Vm-owned_by_current_ldap_group"}} }

      it "sets @named_scope to :with_miq_group" do
        subject.send(:set_named_scope)
        expect(named_scope).to eq(:with_miq_group)
      end
    end
  end

  describe "#miq_search_exp_fields" do
    context "if @edit and session or not set" do
      it "returns an empty_array" do
        expect(subject.send(:miq_search_exp_fields)).to eq([])
      end
    end

    context "if @edit is set" do
      context "without [:adv_search_applied][:qs_exp]" do
        let(:edit) { {} }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "when [:adv_search_applied] is nil" do
        let(:edit) { {} }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "with an empty search" do
        let(:edit) { empty_search }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "with an valid exp" do
        let(:edit) { exp }
        it "returns the fields in an array" do
          expect(subject.send(:miq_search_exp_fields)).to eq(["name"])
        end
      end

      context "with an valid qs_exp" do
        let(:edit) { qs_exp }
        it "returns the fields in an array" do
          expect(subject.send(:miq_search_exp_fields)).to eq(["name"])
        end
      end
    end

    context "if session[:edit] is set" do
      context "without [:adv_search_applied][:qs_exp]" do
        let(:my_session) { {:edit => {}} }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "when [:adv_search_applied] is nil" do
        let(:edit) { {} }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "with an empty search" do
        let(:my_session) { {:edit => empty_search} }
        it "returns an empty_array" do
          expect(subject.send(:miq_search_exp_fields)).to eq([])
        end
      end

      context "with an valid exp" do
        let(:my_session) { {:edit => exp} }
        it "returns the fields in an array" do
          expect(subject.send(:miq_search_exp_fields)).to eq(["name"])
        end
      end

      context "with an valid qs_exp" do
        let(:my_session) { {:edit => qs_exp} }
        it "returns the fields in an array" do
          expect(subject.send(:miq_search_exp_fields)).to eq(["name"])
        end
      end
    end
  end
end
