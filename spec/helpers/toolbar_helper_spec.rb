describe ToolbarHelper do
  describe "#buttons_to_html" do
    subject { buttons_to_html(buttons) }

    let(:buttons) do
      [
        {
          :id       => "history_choice",
          :type     => "buttonSelect",
          :img      => "history.png",
          :imgdis   => "history.png",
          :icon     => nil,
          :title    => "History",
          :enabled  => false,
          :items    => [
            {
              :id      => "history_choice__history_1",
              :type    => "button",
              :img     => "history.png",
              :imgdis  => "history.png",
              :icon    => nil,
              :enabled => "false",
              :title   => "Go to this item",
              :name    => "history_choice__history_1",
              :hidden  => false,
              :pressed => nil,
              :onwhen  => nil,
              :url     => "x_history?item=1"
            }
          ],
          :hidden   => false,
          :name     => "history_choice",
          :pressed  => nil,
          :onwhen   => nil,
          :explorer => true
        },
        {
          :id      => "summary_reload",
          :type    => "button",
          :img     => "reload.png",
          :imgdis  => "reload.png",
          :icon    => nil,
          :title   => "Reload current display",
          :name    => "summary_reload",
          :hidden  => false,
          :pressed => nil,
          :onwhen  => nil,
          :url     => "reload"
        }
      ]
    end

    it "renders normal toolbar buttons as <button>" do
      expect(subject).to have_selector('button', :count => 2)
    end

    it "renders drop-down items as <li>" do
      expect(subject).to have_selector('ul.dropdown-menu li', :count => 1)
    end

    it "renders view buttons as <ul>" do
      expect(subject).to have_selector('ul')
    end

    it "wraps top buttons into <div> with class of 'form-group'" do
      expect(subject).to have_selector('div.form-group')
    end

    context 'with separator' do
      let(:buttons) do
        [
          {
            :id    => "view_grid",
            :type  => "buttonTwoState",
            :img   => "view_grid.png",
            :icon  => "fa fa-th",
            :title => "Grid View",
            :name  => "view_grid",
          },
          {
            :type => "separator"
          },
          {
            :id    => "view_tile",
            :type  => "buttonTwoState",
            :img   => "view_tile.png",
            :icon  => "fa fa-th-large",
            :title => "Tile View",
            :name  => "view_tile",
          }
        ]
      end
      it "splits top buttons into groups on separator" do
        expect(subject).to have_selector('div.form-group', :count => 2)
      end
    end

    context 'with icon' do
      let(:buttons) do
        [
          {
            :id    => "view_grid",
            :type  => "buttonTwoState",
            :img   => "view_grid.png",
            :icon  => "fa fa-th",
            :title => "Grid View",
            :name  => "view_grid",
          },
          {
            :id    => "view_tile",
            :type  => "buttonTwoState",
            :img   => "view_tile.png",
            :icon  => "fa fa-th-large",
            :title => "Tile View",
            :name  => "view_tile",
          }
        ]
      end

      it 'renders icons instead of images' do
        expect(subject).to have_selector('i.fa', :count => 2)
        expect(subject).not_to have_selector('img')
      end
    end
  end

  describe "#view_mode_buttons" do
    subject { view_mode_buttons(buttons) }

    let(:buttons) do
      [
        {
          :id        => "view_grid",
          :type      => "buttonTwoState",
          :img       => "view_grid.png",
          :imgdis    => "view_grid.png",
          :icon      => "fa fa-th",
          :title     => "Grid View",
          :enabled   => "false",
          :selected  => "true",
          :name      => "view_grid",
          :hidden    => false,
          :pressed   => nil,
          :onwhen    => nil,
          :url       => "explorer",
          :url_parms => "?type=grid"
        },
        {
          :id        => "view_tile",
          :type      => "buttonTwoState",
          :img       => "view_tile.png",
          :imgdis    => "view_tile.png",
          :icon      => "fa fa-th-large",
          :title     => "Tile View",
          :name      => "view_tile",
          :hidden    => false,
          :pressed   => nil,
          :onwhen    => nil,
          :url       => "explorer",
          :url_parms => "?type=tile"
        }
      ]
    end

    it 'renders ul with items, links and icons' do
      expect(subject).to have_selector('ul li', :count => 2)
      expect(subject).to have_selector('li a i.fa.fa-th')
    end
  end

  describe "#data_hash_keys" do
    it "returns hash without elements with nil value" do
      output_hash = data_hash_keys(:pressed => nil, :explorer => true)
      expect(output_hash['data-explorer']).to be_truthy
      expect(output_hash).not_to have_key('data-pressed')
    end

    it "converts :url_parms do data-url_parms" do
      output_hash = data_hash_keys(:url_parms => 'foobar')
      expect(output_hash['data-url_parms']).to eq('foobar')
    end
  end
end
