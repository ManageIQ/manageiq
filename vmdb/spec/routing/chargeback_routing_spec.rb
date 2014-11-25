require 'spec_helper'

describe 'routes for ChargebackController' do
  let(:controller_name) { 'chargeback' }

  describe '#accordion_select' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/accordion_select")).to route_to("#{controller_name}#accordion_select")
    end
  end

  describe '#cb_assign_field_changed' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_assign_field_changed")).to route_to(
                                                                      "#{controller_name}#cb_assign_field_changed"
                                                                    )
    end
  end

  describe '#cb_assign_update' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_assign_update")).to route_to("#{controller_name}#cb_assign_update")
    end
  end

  describe '#cb_rate_edit' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_rate_edit")).to route_to("#{controller_name}#cb_rate_edit")
    end
  end

  describe '#cb_rate_form_field_changed' do
    it 'routes with POST' do
      expect(
        post("/#{controller_name}/cb_rate_form_field_changed")
      ).to route_to("#{controller_name}#cb_rate_form_field_changed")
    end
  end

  describe '#cb_rate_show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_rate_show")).to route_to("#{controller_name}#cb_rate_show")
    end
  end

  describe '#cb_rates_delete' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_rates_delete")).to route_to("#{controller_name}#cb_rates_delete")
    end
  end

  describe '#cb_rates_list' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/cb_rates_list")).to route_to("#{controller_name}#cb_rates_list")
    end
  end

  describe '#explorer' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end

    it 'routes with POST' do
      expect(post("/#{controller_name}/explorer")).to route_to("#{controller_name}#explorer")
    end
  end

  describe '#index' do
    it 'routes with GET' do
      expect(get("/#{controller_name}")).to route_to("#{controller_name}#index")
    end
  end

  describe '#render_csv' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/render_csv")).to route_to("#{controller_name}#render_csv")
    end
  end

  describe '#render_pdf' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/render_pdf")).to route_to("#{controller_name}#render_pdf")
    end
  end

  describe '#render_txt' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/render_txt")).to route_to("#{controller_name}#render_txt")
    end
  end

  describe '#report_only' do
    it 'routes with GET' do
      expect(get("/#{controller_name}/report_only")).to route_to("#{controller_name}#report_only")
    end
  end

  describe '#x_show' do
    it 'routes with POST' do
      expect(post("/#{controller_name}/x_show")).to route_to("#{controller_name}#x_show")
    end
  end
end
