RSpec.describe ChargebackContainerProject do
  include Spec::Support::ChargebackHelper

  let(:base_options) { {:interval_size => 2, :end_interval_offset => 0, :ext_options => {:tz => 'UTC'}} }
  let(:hourly_rate) { 0.01 }
  let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
  let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(base_options[:ext_options])) }
  let(:report_run_time) { month_end }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryBot.create(:ems_openshift) }

  let(:hourly_variable_tier_rate) { {:variable_rate => hourly_rate.to_s} }

  let(:detail_params) do
    {
      :chargeback_rate_detail_fixed_compute_cost => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_cpu_cores_used     => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_net_io_used        => {:tiers => [hourly_variable_tier_rate]},
      :chargeback_rate_detail_memory_used        => {:tiers => [hourly_variable_tier_rate]}
    }
  end

  let!(:chargeback_rate) do
    FactoryBot.create(:chargeback_rate, :detail_params => detail_params)
  end

  let(:metric_rollup_params) { {:parent_ems_id => ems.id, :tag_names => ""} }

  def cpu_cores_used_metric_for(project, hours)
    metric_used = used_average_for(:cpu_usage_rate_average, hours, project)
    derived_vm_numvcpus = used_average_for(:derived_vm_numvcpus, project.metric_rollups.count, project)

    (metric_used * derived_vm_numvcpus) / 100.00
  end

  before do
    ChargebackRateDetailMeasure.seed
    ChargeableField.seed
    MiqEnterprise.seed
    ManageIQ::Showback::InputMeasure.seed

    EvmSpecHelper.local_miq_server
    @project = FactoryBot.create(:container_project, :name => "my project", :ext_management_system => ems,
                                  :created_on => month_beginning)

    temp = {:cb_rate => chargeback_rate, :object => ems}
    ChargebackRate.set_assignments(:compute, [temp])

    cat = FactoryBot.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryBot.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    @tag = c.tag
    @project.tag_with(@tag.name, :ns => '*')

    Timecop.travel(report_run_time)
  end

  after do
    Timecop.return
  end

  context "Daily" do
    let(:hours_in_day) { 24 }
    let(:options) { base_options.merge(:interval => 'daily', :entity_id => @project.id, :tag => nil) }
    let(:start_time)  { report_run_time - 17.hours }
    let(:finish_time) { report_run_time - 14.hours }

    before do
      add_metric_rollups_for(@project, start_time...finish_time, 1.hour, metric_rollup_params)
      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    context 'when first metric rollup has tag_names=nil' do
      before do
        @project.metric_rollups.first.update(:tag_names => nil)
      end

      it "cpu" do
        metric_used = cpu_cores_used_metric_for(@project, hours_in_day)
        expect(subject.cpu_cores_used_metric).to eq(metric_used)
        expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
      end
    end

    it "cpu" do
      metric_used = cpu_cores_used_metric_for(@project, hours_in_day)
      expect(subject.cpu_cores_used_metric).to eq(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "memory" do
      metric_used = used_average_for(:derived_memory_used, hours_in_day, @project)
      expect(subject.memory_used_metric).to eq(metric_used)
      expect(subject.memory_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "net io" do
      metric_used = used_average_for(:net_usage_rate_average, hours_in_day, @project)
      expect(subject.net_io_used_metric).to eq(metric_used)
      expect(subject.net_io_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_day)
    end

    it "fixed_compute" do
      expect(subject.fixed_compute_1_cost).to eq(hourly_rate * hours_in_day)
      expect(subject.fixed_compute_metric).to eq(@metric_size)
    end
  end

  context "Monthly" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    before do
      add_metric_rollups_for(@project, month_beginning...month_end, 12.hours, metric_rollup_params)
      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = cpu_cores_used_metric_for(@project, hours_in_month)
      expect(subject.cpu_cores_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "memory" do
      metric_used = used_average_for(:derived_memory_used, hours_in_month, @project)
      expect(subject.memory_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.memory_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "net io" do
      metric_used = used_average_for(:net_usage_rate_average, hours_in_month, @project)
      expect(subject.net_io_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.net_io_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      expect(subject.fixed_compute_metric).to eq(@metric_size)
    end
  end

  context "tagged project" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => nil, :tag => '/managed/environment/prod') }

    before do
      add_metric_rollups_for(@project, month_beginning...month_end, 12.hours, metric_rollup_params)
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "cpu" do
      metric_used = cpu_cores_used_metric_for(@project, hours_in_month)
      expect(subject.cpu_cores_used_metric).to be_within(0.01).of(metric_used)
      expect(subject.cpu_cores_used_cost).to be_within(0.01).of(metric_used * hourly_rate * hours_in_month)
    end

    context "multiple tags" do
      let(:base_filter_options) do
        base_options.merge(:interval => 'monthly', :entity_id => nil, :provider_id => 'all', :groupby => 'date')
      end

      let(:options) { base_filter_options }

      let(:other_project) do
        FactoryBot.create(:container_project, :name                  => "Other Project",
                                              :ext_management_system => ems,
                                              :created_on            => month_beginning)
      end

      let(:development_project) do
        FactoryBot.create(:container_project, :name                  => "Development Project",
                                              :ext_management_system => ems,
                                              :created_on            => month_beginning)
      end

      subject do
        ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.map { |x| x.entity.id }
      end

      before do
        environment_category = Classification.find_by(:description => "Environment")
        tag_development = FactoryBot.create(:classification, :name => "dev", :description => "Development", :parent_id => environment_category.id)

        development_project.tag_with(tag_development.tag.name, :ns => '*')

        add_metric_rollups_for(other_project, month_beginning...month_end, 12.hours, metric_rollup_params)
        add_metric_rollups_for(development_project, month_beginning...month_end, 12.hours, metric_rollup_params)
        add_metric_rollups_for(@project, month_beginning...month_end, 12.hours, metric_rollup_params)
      end

      it "doesn't filter resources without filter" do
        expect(subject).to match_array(ContainerProject.ids)
      end

      context "with filter" do
        let(:options) do
          base_filter_options.merge(:tag => '/managed/environment/prod')
        end

        it "filters resources according to tag" do
          expect(subject).to match_array([@project.id])
        end

        context "with multiple tags filter" do
          let(:options) do
            base_filter_options.merge(:tag => ['/managed/environment/prod', '/managed/environment/dev'])
          end

          it "filters resources according to multiple tags" do
            expect(subject).to match_array([@project.id, development_project.id])
          end
        end
      end
    end
  end

  context "group results by tag" do
    let(:options) do
      base_options.merge(:interval => 'monthly', :entity_id => nil, :provider_id => 'all', :groupby_tag => 'environment')
    end

    let(:development_project) do
      FactoryBot.create(:container_project, :name                  => "Development Project",
                                            :ext_management_system => ems,
                                            :created_on            => month_beginning)
    end

    let(:other_development_project) do
      FactoryBot.create(:container_project, :name                  => "Other Development Project",
                                            :ext_management_system => ems,
                                            :created_on            => month_beginning)
    end

    before do
      environment_category = Classification.find_by(:description => "Environment")
      FactoryBot.create(:classification, :name => "dev", :description => "Development", :parent_id => environment_category.id)

      metric_rollup_params[:tag_names] = "environment/dev"
      add_metric_rollups_for(development_project, month_beginning...month_end, 12.hours, metric_rollup_params)

      metric_rollup_params[:tag_names] = "environment/dev"
      add_metric_rollups_for(other_development_project, month_beginning...month_end, 12.hours, metric_rollup_params)

      metric_rollup_params[:tag_names] = "environment/prod"
      add_metric_rollups_for(@project, month_beginning...month_end, 12.hours, metric_rollup_params)
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first }

    it "cpu" do
      cpu_cores_metric_used = cpu_cores_used_metric_for(@project, hours_in_month)

      expect(subject.first.cpu_cores_used_metric).to be_within(0.01).of(cpu_cores_metric_used)
      expect(subject.first.cpu_cores_used_cost).to be_within(0.01).of(cpu_cores_metric_used * hourly_rate * hours_in_month)
      expect(subject.first.tag_name).to eq('Production')

      metric_used_for_development_project = cpu_cores_used_metric_for(development_project, hours_in_month)
      metric_used_for_other_development_project = cpu_cores_used_metric_for(other_development_project, hours_in_month)
      cpu_cores_metric_used = metric_used_for_development_project + metric_used_for_other_development_project

      expect(subject.second.cpu_cores_used_metric).to be_within(0.01).of(cpu_cores_metric_used)
      expect(subject.second.cpu_cores_used_cost).to be_within(0.01).of(cpu_cores_metric_used * hourly_rate * hours_in_month)
      expect(subject.second.tag_name).to eq('Development')
    end

    context "group by multiple tags" do
      let(:options) do
        base_options.merge(:interval => 'monthly', :entity_id => nil, :provider_id => 'all', :groupby_tag => ['environment', 'department'])
      end

      let(:accounting_project) do
        FactoryBot.create(:container_project, :name => "Department Project", :ext_management_system => ems, :created_on => month_beginning)
      end

      let(:department_tag_category) { FactoryBot.create(:classification_department_with_tags) }
      let!(:accounting_tag)         { department_tag_category.entries.find_by(:description => "Accounting").tag }

      let(:production_result_part)  { subject.detect { |x| x.tag_name == "Production" } }
      let(:development_result_part) { subject.detect { |x| x.tag_name == "Development" } }
      let(:accounting_result_part)  { subject.detect { |x| x.tag_name == "Accounting" } }

      before do
        metric_rollup_params[:tag_names] = "department/accounting"
        add_metric_rollups_for(accounting_project, month_beginning...month_end, 12.hours, metric_rollup_params)
      end

      it "generates results for multiple tags categories" do
        cpu_cores_metric_used = cpu_cores_used_metric_for(accounting_project, hours_in_month)

        expect(accounting_result_part.cpu_cores_used_metric).to be_within(0.01).of(cpu_cores_metric_used)
        expect(accounting_result_part.cpu_cores_used_cost).to be_within(0.01).of(cpu_cores_metric_used * hourly_rate * hours_in_month)

        cpu_cores_metric_used = production_result_part.cpu_cores_used_metric * 2
        expect(development_result_part.cpu_cores_used_metric).to be_within(0.01).of(cpu_cores_metric_used)
        expect(development_result_part.cpu_cores_used_cost).to be_within(0.01).of(cpu_cores_metric_used * hourly_rate * hours_in_month)
      end
    end
  end

  context "ignore empty metrics in fixed_compute" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }

    before do
      add_metric_rollups_for(@project, month_beginning...month_end, 24.hours, metric_rollup_params)

      metric_rollup_params[:cpu_usage_rate_average] = 0.0
      metric_rollup_params[:derived_memory_used] = 0.0

      add_metric_rollups_for(@project, (month_beginning + 12.hours)...month_end, 24.hours, metric_rollup_params, [])

      @metric_size = @project.metric_rollups.size
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      expect(subject.fixed_compute_metric).to eq(@metric_size / 2)
    end
  end

  context "gets rate from enterprise" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    let(:miq_enterprise) { MiqEnterprise.first }

    before do
      add_metric_rollups_for(@project, month_beginning...month_end, 24.hours, metric_rollup_params)

      metric_rollup_params[:cpu_usage_rate_average] = 0.0
      metric_rollup_params[:derived_memory_used] = 0.0

      add_metric_rollups_for(@project, (month_beginning + 12.hours)...month_end, 24.hours, metric_rollup_params, [])

      @metric_size = @project.metric_rollups.size

      temp = {:cb_rate => chargeback_rate, :object => miq_enterprise}
      ChargebackRate.set_assignments(:compute, [temp])
    end

    subject { ChargebackContainerProject.build_results_for_report_ChargebackContainerProject(options).first.first }

    it "fixed_compute" do
      # .to be_within(0.01) is used since theres a float error here
      expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      expect(subject.fixed_compute_metric).to eq(@metric_size / 2)
    end
  end
end
