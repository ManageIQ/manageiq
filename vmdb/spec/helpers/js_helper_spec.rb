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
    "
      $j('#barbox').dynatree('disable');
      miqDimDiv('bar_div',true);
    ")
    end

    it 'returns js to unlock tree' do
      tree_lock('bar',false).should eq(
    "
      $j('#barbox').dynatree('enable');
      miqDimDiv('bar_div',false);
    ")
    end
  end

  context '#update_element' do
  end

  context '#javascript_focus' do
    it 'returns js to focus on an element' do
      javascript_focus('foo').should eq("$j('#foo').focus();")
    end
  end

  context '#javascript_focus_if_exists' do
    it 'returns js to check for the existence of an element and focus on the element if it exists' do
      javascript_focus_if_exists('foo').should eq("if ($j('#foo').length) $j('#foo').focus();")
    end
  end
end
