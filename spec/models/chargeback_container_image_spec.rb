describe ChargebackContainerImage do
  let(:base_options) { {:interval_size => 1, :end_interval_offset => 0, :ext_options => {:tz => 'Pacific Time (US & Canada)'} } }
  let(:hourly_rate)       { 0.01 }
  let(:ts) { Time.now.in_time_zone(Metric::Helper.get_time_zone(options[:ext_options])) }
  let(:month_beginning) { ts.beginning_of_month.utc }
  let(:month_end) { ts.end_of_month.utc }
  let(:hours_in_month) { Time.days_in_month(month_beginning.month, month_beginning.year) * 24 }
  let(:ems) { FactoryGirl.create(:ems_openshift) }

  let(:hourly_variable_tier_rate) { {:variable_rate => hourly_rate.to_s} }

  let(:detail_params) do
    {:chargeback_rate_detail_fixed_compute_cost => { :tiers  => [hourly_variable_tier_rate],
                                                     :detail => { :source => "compute_1"} } }
  end

  let!(:chargeback_rate) do
    FactoryGirl.create(:chargeback_rate, :detail_params => detail_params)
  end

  before do
    MiqRegion.seed
    ChargebackRate.seed

    EvmSpecHelper.create_guid_miq_server_zone
    @node = FactoryGirl.create(:container_node, :name => "node")
    @image = FactoryGirl.create(:container_image, :ext_management_system => ems)
    @label = FactoryGirl.build(:custom_attribute, :name => "version_label-1", :value => "1.0.0-rc_2", :section => 'docker_labels')
    @project = FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems)
    @group = FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => @project,
                                :container_node => @node)
    @container = FactoryGirl.create(:kubernetes_container, :container_group => @group, :container_image => @image)
    cat = FactoryGirl.create(:classification, :description => "Environment", :name => "environment", :single_value => true, :show => true)
    c = FactoryGirl.create(:classification, :name => "prod", :description => "Production", :parent_id => cat.id)
    ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :tag => [c, "container_image"] }])

    @tag = c.tag
    @project.tag_with(@tag.name, :ns => '*')
    @image.tag_with(@tag.name, :ns => '*')

    Timecop.travel(Time.parse("2012-09-01 00:00:00 UTC"))
  end

  after do
    Timecop.return
  end

  context "Daily" do
    let(:hours_in_day) { 24 }
    let(:options) { base_options.merge(:interval => 'daily', :entity_id => @project.id, :tag => nil) }

    before do
      ["2012-08-31T07:00:00Z", "2012-08-31T08:00:00Z", "2012-08-31T09:00:00Z", "2012-08-31T10:00:00Z"].each do |t|
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                        :timestamp                => t,
                                                        :parent_ems_id            => ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
        #state = VimPerformanceState.capture(@container)
        @container.vim_performance_states << FactoryGirl.create(:vim_performance_state,
                                                                :timestamp => t,
                                                                :image_tag_names => "environment/prod")
      end
    end

    subject { ChargebackContainerImage.build_results_for_report_ChargebackContainerImage(options).first.first }

    it "fixed_compute" do
      expect(subject.fixed_compute_1_cost).to eq(hourly_rate * hours_in_day)
    end
  end

  context "Monthly" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    before do
      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                        :timestamp                => time,
                                                        :parent_ems_id            => ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
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
  end

  context "Label" do
    let(:options) { base_options.merge(:interval => 'monthly', :entity_id => @project.id, :tag => nil) }
    before do
      @image.docker_labels << @label
      ChargebackRate.set_assignments(:compute, [{ :cb_rate => chargeback_rate, :label => [@label, "container_image"] }])

      Range.new(month_beginning, month_end, true).step_value(12.hours).each do |time|
        @container.metric_rollups << FactoryGirl.create(:metric_rollup_vm_hr, :with_data,
                                                        :timestamp                => time,
                                                        :parent_ems_id            => ems.id,
                                                        :tag_names                => "",
                                                        :resource_name            => @project.name,
                                                        :resource_id              => @project.id)
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
