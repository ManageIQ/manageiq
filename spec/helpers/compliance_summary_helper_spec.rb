describe ComplianceSummaryHelper do
  before do
    server  = FactoryGirl.build(:miq_server, :id => 0)
    @record = FactoryGirl.build(:vm_vmware, :miq_server => server)
    @compliance1 = FactoryGirl.build(:compliance)
    @compliance2 = FactoryGirl.build(:compliance)
    allow_any_instance_of(described_class).to receive(:role_allows?).and_return(true)
  end

  context "when @explorer is set" do
    before do
      allow(controller).to receive(:controller_name).and_return("vm_infra")
      allow(controller.class).to receive(:model).and_return(VmOrTemplate)
      @explorer = true
    end

    it "#textual_compliance_status" do
      @record.compliances = [@compliance1]
      date = @compliance1.timestamp
      expect(helper.textual_compliance_status).to eq(:label    => "Status",
                                                     :image    => "100/check.png",
                                                     :value    => "Compliant as of #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago",
                                                     :title    => "Show Details of Compliance Check on #{format_timezone(date)}",
                                                     :explorer => true,
                                                     :link     => "/vm_infra/show?count=1&display=compliance_history")
    end

    it "#textual_compliance_history" do
      @record.compliances = [@compliance1, @compliance2]
      expect(helper.textual_compliance_history).to eq(:label    => "History",
                                                      :image    => "100/compliance.png",
                                                      :value    => "Available",
                                                      :explorer => true,
                                                      :title    => "Show Compliance History of this VM or Template (Last 10 Checks)",
                                                      :link     => "/vm_infra/show?display=compliance_history")
    end
  end

  context "for classic screens when @explorer is not set" do
    before do
      allow(controller).to receive(:controller_name).and_return("host")
      allow(controller.class).to receive(:model).and_return(Host)
    end

    it "#textual_compliance_status" do
      @record.compliances = [@compliance1]
      date = @compliance1.timestamp
      expect(helper.textual_compliance_status).to eq(:label => "Status",
                                                     :image => "100/check.png",
                                                     :value => "Compliant as of #{time_ago_in_words(date.in_time_zone(Time.zone)).titleize} Ago",
                                                     :title => "Show Details of Compliance Check on #{format_timezone(date)}",
                                                     :link  => "/host/show?count=1&display=compliance_history")
    end

    it "#textual_compliance_history" do
      @record.compliances = [@compliance1, @compliance2]
      expect(helper.textual_compliance_history).to eq(:label => "History",
                                                      :image => "100/compliance.png",
                                                      :value => "Available",
                                                      :title => "Show Compliance History of this Host / Node (Last 10 Checks)",
                                                      :link  => "/host/show?display=compliance_history")
    end
  end
end
