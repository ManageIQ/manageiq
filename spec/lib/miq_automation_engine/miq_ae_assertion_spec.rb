describe MiqAeEngine::MiqAeObject do
  include Spec::Support::AutomationHelper

  context "Expression" do
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:instance_name) { 'FRED' }
    let(:ae_instances) do
      {instance_name => {'guard' => {:value => assert_value},
                         'var1'  => {:value => "ok"}}}
    end

    let(:ae_fields) do
      {'guard' => {:aetype => 'assertion', :datatype => 'string'},
       'var1'  => {:aetype => 'attribute', :datatype => 'string'}}
    end

    let(:ae_model) do
      create_ae_model(:name => 'LUIGI', :ae_class => 'BARNEY',
                      :ae_namespace => 'A/C',
                      :ae_fields => ae_fields, :ae_instances => ae_instances)
    end

    context "valid expression" do
      let(:assert_value) { "true" }

      it "returns success" do
        ae_model
        workspace = MiqAeEngine.instantiate('/A/C/BARNEY/FRED', user)

        expect(workspace.root['var1']).to eq("ok")
      end
    end

    context "missing object" do
      let(:assert_value) { "${/missing_object#var1}" }

      it "raises InvalidPathFormat" do
        ae_model

        expect do
          MiqAeEngine.instantiate('/A/C/BARNEY/FRED', user)
        end.to raise_exception(MiqAeException::InvalidPathFormat)
      end
    end

    context "missing attribute" do
      let(:assert_value) { "${/#var1}" }

      it "raises AttributeNotFound" do
        ae_model

        expect do
          MiqAeEngine.instantiate('/A/C/BARNEY/FRED', user)
        end.to raise_exception(MiqAeException::AttributeNotFound)
      end
    end
  end
end
