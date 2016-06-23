require "spec_helper"
include ChartingHelper

describe 'layouts/_perf_chart_js.html.haml' do
  context do
    chart_data = [{:xml     => {},
                  :main_col => "cpu_usagemhz_rate_average",
                  :menu     => ["Chart-Current-Daily:Back to daily", "Timeline-Current-Hourly:Hourly events on this VM"],
                  :zoom_url => "javascript:miqAsyncAjax('/vm_infra/perf_chart_chooser/10000000000011?chart_idx=0')"}]

  chart_data2 = [{:xml => {}, :xml2 => {},
                  :main_col => "cpu_usagemhz_rate_average",
                  :menu     => ["Chart-Current-Daily:Back to daily", "Timeline-Current-Hourly:Hourly events on this VM"],
                  :zoom_url => "javascript:miqAsyncAjax('/vm_infra/perf_chart_chooser/10000000000011?chart_idx=0')"}]

  charts = [{:title              => "CPU (Mhz)",
             :type               => "Line",
             :columns            => ["cpu_usagemhz_rate_average"],
             :menu               => ["Chart-Current-Daily:Back to daily", "Timeline-Current-Hourly:Hourly events on this VM"],
             :applies_to_method  => "cpu_mhz_available?"}]


    it 'have correct structure for chart interactivity with simple chart' do
      render :partial => '/layouts/perf_chart_js.html.haml', :locals => {:chart_data => chart_data, :chart_index => 0, :chart_set => 'candu', :charts => charts}
      expect(response).to include("<div class='chart_parent' id='miq_chart_parent_candu_0' style='margin-bottom: 50px'>\n<div>\n<div class='card-pf-heading'>\n<h2 class='card-pf-title'>CPU (Mhz)</h2>\n</div>\n<div class='card-pf-body'>\n<div class='overlay-container' style='position: relative'>\n<div id=\"miq_chart_candu_0\"></div>\n<div class='overlay' style='display: none; position: absolute; top: 0; left: 0; bottom: 0; right: 0; z-index: 500'></div>\n</div>")
    end

    it 'have correct structure for chart interactivity with composite chart' do
      render :partial => '/layouts/perf_chart_js.html.haml', :locals => {:chart_data => chart_data2, :chart_index => 0, :chart_set => 'candu', :charts => charts}
      expect(response).to include("div class='chart_parent' id='miq_chart_parent_candu_0'>\n<div>\n<div class='card-pf-heading'>\n<h2 class='card-pf-title'>CPU (Mhz)</h2>\n</div>\n<div class='overlay-container' style='position: relative'>\n<div class='card-pf-body'>\n<div id=\"miq_chart_candu_0\"></div>\n<div class='overlay' style='display: none; position: absolute; top: 0; left: 0; bottom: 0; right: 0; z-index: 500'></div>\n</div>\n</div>\n</div>")
      expect(response).to include("div class='chart_parent' id='miq_chart_parent_candu_0_2'>\n<div>\n<div class='overlay-container' style='position: relative'>\n<div class='card-pf-body'>\n<div id=\"miq_chart_candu_0_2\"></div>\n<div class='overlay' style='display: none; position: absolute; top: 0; left: 0; bottom: 0; right: 0; z-index: 500'></div>\n</div>\n</div>\n</div>")
    end
  end

end
