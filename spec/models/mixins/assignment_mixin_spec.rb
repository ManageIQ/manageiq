describe AssignmentMixin do
  # too ingrained in AR - has many, acts_as_miq_taggable, ...
  let(:test_class) { MiqAlertSet }

  describe '#get_assigned_for_target' do
    context 'searching for ChargebackRate' do
      let(:test_class) { ChargebackRate }
      let(:vm)              { FactoryGirl.create(:vm_openstack) }
      let(:hardware)        { FactoryGirl.create(:hardware, :vm_or_template_id => vm.id) }
      let(:cloud_volume)    { FactoryGirl.create(:cloud_volume, :hardwares => [hardware]) }
      let(:chargeback_rate) { FactoryGirl.create(:chargeback_rate, :rate_type => 'Storage') }

      before do
        ct1 = ctag("environment", "test1")
        chargeback_rate.assign_to_tags([ct1], "storage")
        cloud_volume.tag_add('environment/test1', :ns => '/managed')
      end

      it 'returns rates based on tagged cloud volume' do
        result = test_class.get_assigned_for_target(vm, :parents => [cloud_volume])
        expect(result).to match_array([chargeback_rate])
      end
    end
  end

  describe '#assignments' do
    it "finds no assignments" do
      expect(test_class.assignments).to eq({})
    end

    it "detects tags on alert_set" do
      ct1 = ctag("environment", "test")
      alert_set = FactoryGirl.create(:miq_alert_set_vm)
      alert_set.assign_to_tags([ct1], "vm")
      alert_set.reload # reload ensures the tag is set

      ct2 = ctag("environment", "staging")
      alert_set2 = FactoryGirl.create(:miq_alert_set_vm)
      alert_set2.assign_to_tags([ct2], "vm")
      alert_set2.reload # reload ensures the tag is set

      expect(test_class.assignments).to eq(
        "vm/tag/managed/environment/test"    => [alert_set],
        "vm/tag/managed/environment/staging" => [alert_set2],
      )
    end
  end

  describe ".all_assignments" do
    it "returns only tags representing assignments" do
      t1 = Tag.create(:name => "/chargeback_rate/assigned_to/vm/tag/managed/environment/any1")
      Tag.create(:name => "/something/with_the same_tag/vm/tag/managed/environment/any1")

      expect(described_class.all_assignments.all).to eq([t1])
    end

    it "returns only tags representing assignments that match tag in argument" do
      Tag.create(:name => "/chargeback_rate/assigned_to/vm/tag/managed/environment/any1")
      t2 = Tag.create(:name => "/chargeback_rate/assigned_to/vm/tag/managed/environment/any2")

      expect(
        described_class.all_assignments("/chargeback_rate/assigned_to/vm/tag/managed/environment/any2").all
      ).to eq([t2])
    end
  end

  private

  # creates a tag e.g. "/managed/environment/test"
  #
  # @param category [String] category name e.g.: "environment"
  # @param value    [String] value e.g.: "test"
  # @return [ClassificationTag] classification tag. `.tag()` is an available method
  def ctag(category = "environment", value = "test")
    env = Classification.find_by_name(category) ||
          FactoryGirl.create(:classification, :name => category, :single_value => 1)
    FactoryGirl.create(:classification_tag, :name => value, :parent => env)
  end
end
