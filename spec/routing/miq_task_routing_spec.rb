describe "routes for MiqTaskController" do
  let(:controller_name) { "miq_task" }

  %w(
    change_tab
    index
    jobs
    tasks_show_option
  ).each do |task|
    describe "##{task}" do
      it 'routes with GET' do
        expect(get("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end

  %w(
    button
    jobs
    tasks_button
    tasks_change_options
  ).each do |task|
    describe "##{task}" do
      it 'routes with POST' do
        expect(post("/#{controller_name}/#{task}")).to route_to("#{controller_name}##{task}")
      end
    end
  end
end
