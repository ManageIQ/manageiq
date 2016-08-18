require 'ostruct'

describe 'report/_schedule_list' do
  context 'flash message is set' do
    helper(JsHelper)

    before do
      assign(:sb, :active_accord => :schedules)
      assign(:schedules, true)
      assign(:view, OpenStruct.new(:table => OpenStruct.new(:data => [])))
      assign(:flash_array, [{:message => 'Find me!', :level => :success}])
    end

    it 'renders the flash message' do
      render
      expect(rendered).to match('Find me!')
    end
  end
end
