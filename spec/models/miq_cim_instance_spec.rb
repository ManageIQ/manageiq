describe MiqCimInstance do
  before do
    @instance1 = FactoryGirl.create(:miq_cim_instance)
    attributes = {
      :result_instance => @instance1,
      :assoc_class     => "A",
      :role            => "B",
      :result_role     => "C"
    }
    @cim_association = FactoryGirl.create(:miq_cim_association, attributes)
    @instance2       = FactoryGirl.create(:miq_cim_instance, :miq_cim_associations => [@cim_association])
  end

  it "#getAssociators" do
    expect(@instance2.getAssociators(:AssocClass => "A", :Role => "B", :ResultRole => "C")
      .collect(&:id))
      .to eq [@instance1.id]
  end

  it "#getAssociatedVmdbObjs" do
    host = FactoryGirl.create(:host)
    @instance1.update_attribute(:vmdb_obj, host)
    expect(@instance2.getAssociatedVmdbObjs(:AssocClass => "A", :Role => "B", :ResultRole => "C"))
      .to eq [host]
  end

  describe '#has_perf_data?' do
    subject { @instance1.has_perf_data? }

    context 'without metrics' do
      it { is_expected.to be_falsey }
    end

    context 'with metrics' do
      let(:rollup) { FactoryGirl.create(:ontap_system_metrics_rollup, :rollup_type => 'hourly') }
      before do
        @instance1.metrics = FactoryGirl.create(:ontap_system_metric, :miq_metrics_rollups => [rollup])
      end
      it { is_expected.to be_truthy }
    end
  end
end
