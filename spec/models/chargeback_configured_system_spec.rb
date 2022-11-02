RSpec.describe ChargebackConfiguredSystem do
  include Spec::Support::ChargebackHelper

  let(:admin) { FactoryBot.create(:user_admin) }
  let(:base_options) do
    {:interval_size       => 2,
     :end_interval_offset => 0,
     :tag                 => '/managed/environment/prod',
     :ext_options         => {:tz => 'UTC'},
     :userid              => admin.userid}
  end
  let(:hourly_rate)               { 0.01 }
  let(:count_hourly_rate)         { 1.00 }
  let(:cpu_count)                 { 1.0 }
  let(:memory_available)          { 1000.0 }
  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(base_options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryBot.create(:ems_vmware) }

  let(:hourly_variable_tier_rate)       { {:variable_rate => hourly_rate.to_s} }
  let(:count_hourly_variable_tier_rate) { {:variable_rate => count_hourly_rate.to_s} }
  let(:fixed_compute_tier_rate)         { {:fixed_rate => hourly_rate.to_s} }

  let(:detail_params) do
    {
      :chargeback_rate_detail_cpu_allocated      => {:tiers => [count_hourly_variable_tier_rate]},
      :chargeback_rate_detail_memory_allocated   => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_fixed_compute_cost => {:tiers => [fixed_compute_tier_rate]}
    }
  end

  let!(:chargeback_rate) do
    FactoryBot.create(:chargeback_rate, :detail_params => detail_params)
  end

  before do
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    ManageIQ::Showback::InputMeasure.seed
    MiqEnterprise.seed

    EvmSpecHelper.local_miq_server
    cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = c.tag
    ChargebackRate.set_assignments(:compute, [{:cb_rate => chargeback_rate, :object => MiqEnterprise.first}])

    @cs = FactoryBot.create(:configured_system, :created_at => report_run_time - 1.day, :computer_system =>
            FactoryBot.create(:computer_system,
                              :hardware => FactoryBot.create(:hardware,
                                                             :cpu_total_cores => cores,
                                                             :memory_mb       => mem_mb)))
    @cs.tag_with(@tag.name, :ns => '*')

    @cs2 = FactoryBot.create(:configured_system, :created_at => report_run_time - 1.day, :computer_system =>
             FactoryBot.create(:computer_system,
                               :hardware => FactoryBot.create(:hardware,
                                                              :cpu_total_cores => cores,
                                                              :memory_mb       => mem_mb)))
    @cs2.tag_with(@tag.name, :ns => '*')
    Timecop.travel(report_run_time)
  end

  after do
    Timecop.return
  end

  context 'without metric rollups' do
    let(:cores)               { 7 }
    let(:mem_mb)              { 1777 }

    let(:fixed_cost) { hourly_rate * 24 }
    let(:mem_cost) { mem_mb * hourly_rate * 24 }
    let(:cpu_cost) { cores * count_hourly_rate * 24 }

    context 'for Configured System' do
      let(:options) { base_options.merge(:interval => 'daily') }

      subject { ChargebackConfiguredSystem.build_results_for_report_ChargebackConfiguredSystem(options).first.first }

      it 'fixed compute/allocated metrics is calculated properly' do
        expect(subject.chargeback_rates).to eq(chargeback_rate.description)
        expect(subject.fixed_compute_metric).to eq(1) # One day of fixed compute metric
        expect(subject.fixed_compute_1_cost).to eq(fixed_cost)
      end

      it 'allocated metrics are calculated properly' do
        expect(subject.memory_allocated_metric).to  eq(mem_mb)
        expect(subject.memory_allocated_cost).to    eq(mem_cost)
        expect(subject.cpu_allocated_metric).to     eq(cores)
        expect(subject.cpu_allocated_cost).to       eq(cpu_cost)
        expect(subject.total_cost).to               eq(fixed_cost + cpu_cost + mem_cost)
      end

      context "group by date" do
        let(:options) { base_options.merge(:groupby => ["date"], :interval => 'daily') }

        subject { ChargebackConfiguredSystem.build_results_for_report_ChargebackConfiguredSystem(options).first.map { |x| x.entity.id } }

        it "groups report by date" do
          expect(subject).to match_array([@cs.id, @cs2.id])
        end
      end
    end
  end
end
