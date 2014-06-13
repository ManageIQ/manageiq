require "spec_helper"

describe JsHelper do
  context '#set_spinner_off' do
    it 'returns js to turn spinner off' do
      set_spinner_off.should eq('miqSparkleOff();')
    end
  end

  context '#set_element_visible' do
    it 'returns js to hide element' do
      set_element_visible('foo',false).should eq("if ($('foo')) $('foo').hide();")
    end

    it 'returns js to show element' do
      set_element_visible('foo',true).should eq("if ($('foo')) $('foo').show();")
    end
  end

  context '#tree_lock' do
    it 'returns js to lock tree' do
      tree_lock('bar',true).should eq(
    " if (typeof bar != 'undefined') {
        bar.lockTree(true);
        miqDimDiv('bar_div',true);
      };
    ")
    end

    it 'returns js to unlock tree' do
      tree_lock('bar',false).should eq(
    " if (typeof bar != 'undefined') {
        bar.lockTree(false);
        miqDimDiv('bar_div',false);
      };
    ")
    end
  end

  context '#update_element' do
  end
end
