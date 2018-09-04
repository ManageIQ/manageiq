describe ChargebackContainerImage do
  shared_examples_for "ChargebackContainerImage" do
    include Spec::Support::ChargebackHelper

    let(:base_options) { {:interval_size => 2, :end_interval_offset => 0, :ext_options => {:tz => 'UTC'} } }
    let(:hourly_rate)       { 0.01 }
    let(:count_hourly_rate) { 1.00 }
    let(:starting_date) { Time.parse('2012-09-01 23:59:59Z').utc }
    let(:ts) { starting_date.in_time_zone(Metric::Helper.get_time_zone(options[:ext_options])) }
    let(:report_run_time) { month_end }
    let(:month_beginning) { ts.beginning_of_month.utc }
    let(:month_end) { ts.end_of_month.utc }
    let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
    let(:ems) { FactoryGirl.create(:ems_openshift) }

    let(:hourly_variable_tier_rate) { {:variable_rate => hourly_rate.to_s} }
    let(:count_hourly_variable_tier_rate) { {:variable_rate => count_hourly_rate.to_s} }

    let(:detail_params) do
      {
        :chargeback_rate_detail_fixed_compute_cost  => {:tiers => [hourly_variable_tier_rate]},
        :chargeback_rate_detail_cpu_cores_allocated => {:tiers => [count_hourly_variable_tier_rate]},
        :chargeback_rate_detail_memory_allocated    => {:tiers => [hourly_variable_tier_rate]}
      }
    end

    let!(:chargeback_rate) do
      FactoryGirl.create(:chargeback_rate, :detail_params => detail_params)
    end

    let(:metric_rollup_params) { {:parent_ems_id => ems.id, :tag_names => ""} }

    before do
      MiqRegion.seed
      ChargebackRateDetailMeasure.seed
      ChargeableField.seed
      MiqEnterprise.seed

      EvmSpecHelper.create_guid_miq_server_zone
      @node = FactoryGirl.create(:container_node, :name => "node")
      @image = FactoryGirl.create(:container_image, :ext_management_system => ems)
      @label = FactoryGirl.build(:custom_attribute, :name => "version/1.2/_label-1", :value => "test/1.0.0  rc_2", :section => 'docker_labels')
      @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems)
      @group = FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => @project,
                                  :container_node => @node)
      @container = FactoryGirl.create(:kubernetes_container, :container_group => @group, :container_image => @image,
                                      :limit_memory_bytes => 1.megabytes, :limit_cpu_cores => 1.0)
      cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
      c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
      ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :tag => [c, "container_image"] }])

      @tag = c.tag
      @project.tag_with(@tag.name, :ns => '*')
      @image.tag_with(@tag.name, :ns => '*')

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
        add_metric_rollups_for(@container, month_beginning...month_end, 12.hours, metric_rollup_params)

        Range.new(start_time, finish_time, true).step_value(1.hour).each do |t|
          @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                  :timestamp => t,
                                                                  :image_tag_names => "environment/prod")
        end
      end

      subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(options).first.first }

      context 'when first metric rollup has tag_names=nil' do
        before do
          @container.metric_rollups.first.update_attributes(:tag_names => nil)
        end

        it "fixed_compute" do
          expect(subject.fixed_compute_1_cost).to eq(hourly_rate * hours_in_day)
        end
      end

      it "fixed_compute" do
        expect(subject.fixed_compute_1_cost).to eq(hourly_rate * hours_in_day)
      end

      it "allocated fields" do
        skip('this feature needs to be added to new chargeback rating') if Settings.new_chargeback
        expect(subject.cpu_cores_allocated_cost).to eq(@container.limit_cpu_cores * count_hourly_rate * hours_in_day)
        expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_cpu_cores)
        expect(subject.cpu_cores_allocated_cost).to eq(@container.limit_memory_bytes / 1.megabytes * count_hourly_rate * hours_in_day)
        expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_memory_bytes / 1.megabytes)
      end
    end

    context "Monthly" do
      let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
      before do
        add_metric_rollups_for(@container, month_beginning...month_end, 12.hours, metric_rollup_params)

        Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
          @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                  :timestamp => time,
                                                                  :image_tag_names => "environment/prod")
        end
      end

      subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(options).first.first }

      it "fixed_compute" do
        # .to be_within(0.01) is used since theres a float error here
        expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      end

      it "allocated fields" do
        skip('this feature needs to be added to new chargeback rating') if Settings.new_chargeback
        expect(subject.cpu_cores_allocated_cost).to eq(@container.limit_cpu_cores * count_hourly_rate * hours_in_month)
        expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_cpu_cores)
        expect(subject.cpu_cores_allocated_cost).to eq(@container.limit_memory_bytes / 1.megabytes * count_hourly_rate * hours_in_month)
        expect(subject.cpu_cores_allocated_metric).to eq(@container.limit_memory_bytes / 1.megabytes)
      end
    end

    context "Label" do
      let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
      before do
        @image.docker_labels << @label
        ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :label => [@label, "container_image"] }])

        add_metric_rollups_for(@container, month_beginning...month_end, 12.hours, metric_rollup_params)

        Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
          @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                  :timestamp => time,
                                                                  :image_tag_names => "")
        end
      end

      subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(options).first.first }

      it "fixed_compute" do
        # .to be_within(0.01) is used since theres a float error here
        expect(subject.fixed_compute_1_cost).to be_within(0.01).of(hourly_rate * hours_in_month)
      end
    end
  end

  context "Old Chargeback" do
    include_examples "ChargebackContainerImage"
  end

  context "New Chargeback" do
    before do
      ManageIQ::Showback::InputMeasure.seed

      stub_settings(:new_chargeback => '1')
    end

    include_examples "ChargebackContainerImage"
  end
end
