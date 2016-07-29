describe ExplorerPresenter do
  context "partial methods" do
    before :each do
      @presenter = ExplorerPresenter.new
      @el        = "test_element"
      @content   = "<div>Sample div element</div>"
    end

    subject { @presenter.for_render }

    context "#replace" do
      it 'adds content to :replacePartials' do

        @presenter.replace(@el, @content)

        expect(subject[:replacePartials]).to include(@el => @content)
      end
    end

    context "#update" do
      it 'adds content to :updatePartials' do
        @presenter.update(@el, @content)

        expect(subject[:updatePartials]).to include(@el => @content)
      end
    end

    context "#[:record_id]" do
      it 'sets :record object' do
        @presenter[:record_id] = 666
        expect(subject[:record][:recordId]).to eq(666)
      end
    end

    context "#ajax_action" do
      it 'sets ajaxUrl to proper url' do
        @presenter[:ajax_action] = {
          :controller => 'foo',
          :action     => 'bar',
          :record_id  => 42,
        }
        expect(subject[:ajaxUrl]).to eq('/foo/bar/42')
      end
    end

    context "#build_calendar" do
      it 'passes data to :buildCalendar' do
        @presenter[:build_calendar] = {:date_from => t = Time.now.utc}
        expect(subject[:buildCalendar]).to include(:date_from => t.iso8601)
      end
    end
  end
end
