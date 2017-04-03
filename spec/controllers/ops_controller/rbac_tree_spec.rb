describe OpsController::RbacTree do
  let(:role) do
    FactoryGirl.create(:miq_user_role, :role => "approver", :features => %w(control_explorer_view dashboard))
  end

  let(:features) { role.miq_product_features.order(:identifier).pluck(:identifier) }

  subject { described_class.new(role, features, false).build }

  before do
    EvmSpecHelper.seed_specific_product_features(%w(control_explorer_view policy_import_export policy))
  end

  it 'builds a hash tree' do
    expect(subject[:children].first[:title]).to eq "Cloud Intel"
  end

  it 'bubbles select states from child to parent' do
    expect(subject[:select]).to eq "undefined"

    control = subject[:children].detect { |c| c[:title] == "Control" }
    explore = control[:children].detect { |c| c[:title] == "Explorer" }
    imp_exp = control[:children].detect { |c| c[:title] == "Import/Export" }

    expect(control[:select]).to eq "undefined"
    expect(explore[:select]).to eq "undefined"
    expect(imp_exp[:select]).to be false
  end

  context "when read-only" do
    it 'sets the checkable key to false' do
      expect(subject[:children].first[:checkable]).to be false
    end
  end

  context "when editable" do
    subject { described_class.new(role, features, true).build }

    it 'sets the checkable key to true' do
      expect(subject[:children].first[:checkable]).to be true
    end
  end
end
