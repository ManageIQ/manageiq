require "spec_helper"

describe ActionView::Helpers::NumberHelper do
  context "#number_to_human_size" do
    # Positive cases taken from Rails helper tests for number_to_human_size to
    #   verify that original method's intent was not changed
    #   https://github.com/rails/rails/blob/v2.3.8/actionpack/test/template/number_helper_test.rb
    # Negative cases added from positive cases.

    it "without options hash" do
      helper.number_to_human_size(0).should               == '0 Bytes'
      helper.number_to_human_size(1).should               == '1 Byte'
      helper.number_to_human_size(3.14159265).should      == '3 Bytes'
      helper.number_to_human_size(123.0).should           == '123 Bytes'
      helper.number_to_human_size(123).should             == '123 Bytes'
      helper.number_to_human_size(1234).should            == '1.2 KB'
      helper.number_to_human_size(12345).should           == '12.1 KB'
      helper.number_to_human_size(1234567).should         == '1.2 MB'
      helper.number_to_human_size(1234567890).should      == '1.1 GB'
      helper.number_to_human_size(1234567890123).should   == '1.1 TB'
      helper.number_to_human_size(1025.terabytes).should  == '1025 TB'
      helper.number_to_human_size(444.kilobytes).should   == '444 KB'
      helper.number_to_human_size(1023.megabytes).should  == '1023 MB'
      helper.number_to_human_size(3.terabytes).should     == '3 TB'
      helper.number_to_human_size("123").should           == '123 Bytes'
      helper.number_to_human_size(1.1).should             == '1 Byte'
      helper.number_to_human_size(10).should              == '10 Bytes'
      helper.number_to_human_size(nil).should             be_nil

      helper.number_to_human_size(-1).should              == '-1 Byte'
      helper.number_to_human_size(-3.14159265).should     == '-3 Bytes'
      helper.number_to_human_size(-123.0).should          == '-123 Bytes'
      helper.number_to_human_size(-123).should            == '-123 Bytes'
      helper.number_to_human_size(-1234).should           == '-1.2 KB'
      helper.number_to_human_size(-12345).should          == '-12.1 KB'
      helper.number_to_human_size(-1234567).should        == '-1.2 MB'
      helper.number_to_human_size(-1234567890).should     == '-1.1 GB'
      helper.number_to_human_size(-1234567890123).should  == '-1.1 TB'
      helper.number_to_human_size(-1025.terabytes).should == '-1025 TB'
      helper.number_to_human_size(-444.kilobytes).should  == '-444 KB'
      helper.number_to_human_size(-1023.megabytes).should == '-1023 MB'
      helper.number_to_human_size(-3.terabytes).should    == '-3 TB'
      helper.number_to_human_size("-123").should          == '-123 Bytes'
      helper.number_to_human_size(-1.1).should            == '-1 Byte'
      helper.number_to_human_size(-10).should             == '-10 Bytes'
    end

    it "with options hash" do
      helper.number_to_human_size(1234567,           :precision => 2).should == '1.18 MB'
      helper.number_to_human_size(3.14159265,        :precision => 4).should == '3 Bytes'
      helper.number_to_human_size(1.0123.kilobytes,  :precision => 2).should == '1.01 KB'
      helper.number_to_human_size(1.0100.kilobytes,  :precision => 4).should == '1.01 KB'
      helper.number_to_human_size(10.000.kilobytes,  :precision => 4).should == '10 KB'
      helper.number_to_human_size(1234567890123,     :precision => 0).should == '1 TB'
      helper.number_to_human_size(524288000,         :precision => 0).should == '500 MB'
      helper.number_to_human_size(41010,             :precision => 0).should == '40 KB'
      helper.number_to_human_size(41100,             :precision => 0).should == '40 KB'

      helper.number_to_human_size(-1234567,          :precision => 2).should == '-1.18 MB'
      helper.number_to_human_size(-3.14159265,       :precision => 4).should == '-3 Bytes'
      helper.number_to_human_size(-1.0123.kilobytes, :precision => 2).should == '-1.01 KB'
      helper.number_to_human_size(-1.0100.kilobytes, :precision => 4).should == '-1.01 KB'
      helper.number_to_human_size(-10.000.kilobytes, :precision => 4).should == '-10 KB'
      helper.number_to_human_size(-1234567890123,    :precision => 0).should == '-1 TB'
      helper.number_to_human_size(-524288000,        :precision => 0).should == '-500 MB'
      helper.number_to_human_size(-41010,            :precision => 0).should == '-40 KB'
      helper.number_to_human_size(-41100,            :precision => 0).should == '-40 KB'
    end

    it "with custom delimiter and separator" do
      helper.number_to_human_size(1.0123.kilobytes,  :precision => 2,   :separator => ',').should == '1,01 KB'
      helper.number_to_human_size(1.0100.kilobytes,  :precision => 4,   :separator => ',').should == '1,01 KB'
      helper.number_to_human_size(1000.1.terabytes,  :delimiter => '.', :separator => ',').should == '1.000,1 TB'

      helper.number_to_human_size(-1.0123.kilobytes, :precision => 2,   :separator => ',').should == '-1,01 KB'
      helper.number_to_human_size(-1.0100.kilobytes, :precision => 4,   :separator => ',').should == '-1,01 KB'
      helper.number_to_human_size(-1000.1.terabytes, :delimiter => '.', :separator => ',').should == '-1.000,1 TB'
    end
  end

  it "#human_size_to_rails_method" do
    helper.human_size_to_rails_method('0 Bytes').should      == '0'
    helper.human_size_to_rails_method('1 Byte').should       == '1'
    helper.human_size_to_rails_method('123 Bytes').should    == '123'
    helper.human_size_to_rails_method('444 KB').should       == '444.kilobytes'
    helper.human_size_to_rails_method('1023 MB').should      == '1023.megabytes'
    helper.human_size_to_rails_method('123 GB').should       == '123.gigabytes'
    helper.human_size_to_rails_method('1025 TB').should      == '1025.terabytes'
    helper.human_size_to_rails_method('123.4 Bytes').should  == '123.4'
    helper.human_size_to_rails_method('12.1 KB').should      == '12.1.kilobytes'
    helper.human_size_to_rails_method('1.2 MB').should       == '1.2.megabytes'
    helper.human_size_to_rails_method('1.1 GB').should       == '1.1.gigabytes'
    helper.human_size_to_rails_method('1.1 TB').should       == '1.1.terabytes'

    helper.human_size_to_rails_method('-1 Byte').should      == '-1'
    helper.human_size_to_rails_method('-123 Bytes').should   == '-123'
    helper.human_size_to_rails_method('-444 KB').should      == '-444.kilobytes'
    helper.human_size_to_rails_method('-1023 MB').should     == '-1023.megabytes'
    helper.human_size_to_rails_method('-123 GB').should      == '-123.gigabytes'
    helper.human_size_to_rails_method('-1025 TB').should     == '-1025.terabytes'
    helper.human_size_to_rails_method('-123.4 Bytes').should == '-123.4'
    helper.human_size_to_rails_method('-12.1 KB').should     == '-12.1.kilobytes'
    helper.human_size_to_rails_method('-1.2 MB').should      == '-1.2.megabytes'
    helper.human_size_to_rails_method('-1.1 GB').should      == '-1.1.gigabytes'
    helper.human_size_to_rails_method('-1.1 TB').should      == '-1.1.terabytes'
  end

  it "#number_to_rails_method" do
    helper.number_to_rails_method(0).should               == '0'
    helper.number_to_rails_method(1).should               == '1'
    helper.number_to_rails_method(3.14159265).should      == '3'
    helper.number_to_rails_method(123.0).should           == '123'
    helper.number_to_rails_method(123).should             == '123'
    helper.number_to_rails_method(1234).should            == '1.2.kilobytes'
    helper.number_to_rails_method(12345).should           == '12.1.kilobytes'
    helper.number_to_rails_method(1234567).should         == '1.2.megabytes'
    helper.number_to_rails_method(1234567890).should      == '1.1.gigabytes'
    helper.number_to_rails_method(1234567890123).should   == '1.1.terabytes'
    helper.number_to_rails_method(1025.terabytes).should  == '1025.terabytes'
    helper.number_to_rails_method(444.kilobytes).should   == '444.kilobytes'
    helper.number_to_rails_method(1023.megabytes).should  == '1023.megabytes'
    helper.number_to_rails_method(3.terabytes).should     == '3.terabytes'
    helper.number_to_rails_method("123").should           == '123'
    helper.number_to_rails_method(1.1).should             == '1'
    helper.number_to_rails_method(10).should              == '10'
    helper.number_to_rails_method(nil).should             be_nil

    helper.number_to_rails_method(-1).should              == '-1'
    helper.number_to_rails_method(-3.14159265).should     == '-3'
    helper.number_to_rails_method(-123.0).should          == '-123'
    helper.number_to_rails_method(-123).should            == '-123'
    helper.number_to_rails_method(-1234).should           == '-1.2.kilobytes'
    helper.number_to_rails_method(-12345).should          == '-12.1.kilobytes'
    helper.number_to_rails_method(-1234567).should        == '-1.2.megabytes'
    helper.number_to_rails_method(-1234567890).should     == '-1.1.gigabytes'
    helper.number_to_rails_method(-1234567890123).should  == '-1.1.terabytes'
    helper.number_to_rails_method(-1025.terabytes).should == '-1025.terabytes'
    helper.number_to_rails_method(-444.kilobytes).should  == '-444.kilobytes'
    helper.number_to_rails_method(-1023.megabytes).should == '-1023.megabytes'
    helper.number_to_rails_method(-3.terabytes).should    == '-3.terabytes'
    helper.number_to_rails_method("-123").should          == '-123'
    helper.number_to_rails_method(-1.1).should            == '-1'
    helper.number_to_rails_method(-10).should             == '-10'
  end

  it "#human_size_to_number" do
    helper.human_size_to_number('0 Bytes').should      == 0
    helper.human_size_to_number('1 Byte').should       == 1
    helper.human_size_to_number('123 Bytes').should    == 123
    helper.human_size_to_number('444 KB').should       == 444.kilobytes
    helper.human_size_to_number('1023 MB').should      == 1023.megabytes
    helper.human_size_to_number('123 GB').should       == 123.gigabytes
    helper.human_size_to_number('1025 TB').should      == 1025.terabytes
    helper.human_size_to_number('123.4 Bytes').should  == 123.4
    helper.human_size_to_number('12.1 KB').should      == 12.1.kilobytes
    helper.human_size_to_number('1.2 MB').should       == 1.2.megabytes
    helper.human_size_to_number('1.1 GB').should       == 1.1.gigabytes
    helper.human_size_to_number('1.1 TB').should       == 1.1.terabytes

    helper.human_size_to_number('-1 Byte').should      == -1
    helper.human_size_to_number('-123 Bytes').should   == -123
    helper.human_size_to_number('-444 KB').should      == -444.kilobytes
    helper.human_size_to_number('-1023 MB').should     == -1023.megabytes
    helper.human_size_to_number('-123 GB').should      == -123.gigabytes
    helper.human_size_to_number('-1025 TB').should     == -1025.terabytes
    helper.human_size_to_number('-123.4 Bytes').should == -123.4
    helper.human_size_to_number('-12.1 KB').should     == -12.1.kilobytes
    helper.human_size_to_number('-1.2 MB').should      == -1.2.megabytes
    helper.human_size_to_number('-1.1 GB').should      == -1.1.gigabytes
    helper.human_size_to_number('-1.1 TB').should      == -1.1.terabytes
  end

  it "#rails_method_to_human_size" do
    helper.rails_method_to_human_size('0').should               == '0 Bytes'
    helper.rails_method_to_human_size('1').should               == '1 Byte'
    helper.rails_method_to_human_size('123').should             == '123 Bytes'
    helper.rails_method_to_human_size('0.bytes').should         == '0 Bytes'
    helper.rails_method_to_human_size('1.bytes').should         == '1 Byte'
    helper.rails_method_to_human_size('123.bytes').should       == '123 Bytes'
    helper.rails_method_to_human_size('444.kilobytes').should   == '444 KB'
    helper.rails_method_to_human_size('1023.megabytes').should  == '1023 MB'
    helper.rails_method_to_human_size('123.gigabytes').should   == '123 GB'
    helper.rails_method_to_human_size('1025.terabytes').should  == '1025 TB'
    helper.rails_method_to_human_size('123.4').should           == '123 Bytes' # rounds bytes
    helper.rails_method_to_human_size('123.4.bytes').should     == '123 Bytes' # rounds bytes
    helper.rails_method_to_human_size('12.1.kilobytes').should  == '12.1 KB'
    helper.rails_method_to_human_size('1.2.megabytes').should   == '1.2 MB'
    helper.rails_method_to_human_size('1.1.gigabytes').should   == '1.1 GB'
    helper.rails_method_to_human_size('1.1.terabytes').should   == '1.1 TB'

    helper.rails_method_to_human_size('-1').should              == '-1 Byte'
    helper.rails_method_to_human_size('-123').should            == '-123 Bytes'
    helper.rails_method_to_human_size('-1.bytes').should        == '-1 Byte'
    helper.rails_method_to_human_size('-123.bytes').should      == '-123 Bytes'
    helper.rails_method_to_human_size('-444.kilobytes').should  == '-444 KB'
    helper.rails_method_to_human_size('-1023.megabytes').should == '-1023 MB'
    helper.rails_method_to_human_size('-123.gigabytes').should  == '-123 GB'
    helper.rails_method_to_human_size('-1025.terabytes').should == '-1025 TB'
    helper.rails_method_to_human_size('-123.4').should          == '-123 Bytes' # rounds bytes
    helper.rails_method_to_human_size('-123.4.bytes').should    == '-123 Bytes' # rounds bytes
    helper.rails_method_to_human_size('-12.1.kilobytes').should == '-12.1 KB'
    helper.rails_method_to_human_size('-1.2.megabytes').should  == '-1.2 MB'
    helper.rails_method_to_human_size('-1.1.gigabytes').should  == '-1.1 GB'
    helper.rails_method_to_human_size('-1.1.terabytes').should  == '-1.1 TB'
  end

  context "#mhz_to_human_size" do
    it "without options hash" do
      helper.mhz_to_human_size(0).should               == '0 MHz'
      helper.mhz_to_human_size(1).should               == '1 MHz'
      helper.mhz_to_human_size(3.14159265).should      == '3.1 MHz'
      helper.mhz_to_human_size(123.0).should           == '123 MHz'
      helper.mhz_to_human_size(123).should             == '123 MHz'
      helper.mhz_to_human_size(1234).should            == '1.2 GHz'
      helper.mhz_to_human_size(12345).should           == '12.3 GHz'
      helper.mhz_to_human_size(1234567).should         == '1.2 THz'
      helper.mhz_to_human_size(1234567890).should      == '1234.6 THz'
      helper.mhz_to_human_size(1234567890123).should   == '1234567.9 THz'
      helper.mhz_to_human_size("123").should           == '123 MHz'
      helper.mhz_to_human_size(nil).should             be_nil

      helper.mhz_to_human_size(-1).should              == '-1 MHz'
      helper.mhz_to_human_size(-3.14159265).should     == '-3.1 MHz'
      helper.mhz_to_human_size(-123.0).should          == '-123 MHz'
      helper.mhz_to_human_size(-123).should            == '-123 MHz'
      helper.mhz_to_human_size(-1234).should           == '-1.2 GHz'
      helper.mhz_to_human_size(-12345).should          == '-12.3 GHz'
      helper.mhz_to_human_size(-1234567).should        == '-1.2 THz'
      helper.mhz_to_human_size(-1234567890).should     == '-1234.6 THz'
      helper.mhz_to_human_size(-1234567890123).should  == '-1234567.9 THz'
      helper.mhz_to_human_size("-123").should          == '-123 MHz'
    end

    it "with options hash" do
      helper.mhz_to_human_size(1234567,        :precision => 2).should == '1.23 THz'
      helper.mhz_to_human_size(3.14159265,     :precision => 4).should == '3.1416 MHz'
      helper.mhz_to_human_size(1234567890123,  :precision => 0).should == '1234568 THz'
      helper.mhz_to_human_size(524288000,      :precision => 0).should == '524 THz'
      helper.mhz_to_human_size(41010,          :precision => 0).should == '41 GHz'
      helper.mhz_to_human_size(41100,          :precision => 0).should == '41 GHz'

      helper.mhz_to_human_size(-1234567,       :precision => 2).should == '-1.23 THz'
      helper.mhz_to_human_size(-3.14159265,    :precision => 4).should == '-3.1416 MHz'
      helper.mhz_to_human_size(-1234567890123, :precision => 0).should == '-1234568 THz'
      helper.mhz_to_human_size(-524288000,     :precision => 0).should == '-524 THz'
      helper.mhz_to_human_size(-41010,         :precision => 0).should == '-41 GHz'
      helper.mhz_to_human_size(-41100,         :precision => 0).should == '-41 GHz'
    end

    it "with old precision argument" do
      helper.mhz_to_human_size(1234567,        2).should == '1.23 THz'
      helper.mhz_to_human_size(3.14159265,     4).should == '3.1416 MHz'
      helper.mhz_to_human_size(1234567890123,  0).should == '1234568 THz'
      helper.mhz_to_human_size(524288000,      0).should == '524 THz'
      helper.mhz_to_human_size(41010,          0).should == '41 GHz'
      helper.mhz_to_human_size(41100,          0).should == '41 GHz'

      helper.mhz_to_human_size(-1234567,       2).should == '-1.23 THz'
      helper.mhz_to_human_size(-3.14159265,    4).should == '-3.1416 MHz'
      helper.mhz_to_human_size(-1234567890123, 0).should == '-1234568 THz'
      helper.mhz_to_human_size(-524288000,     0).should == '-524 THz'
      helper.mhz_to_human_size(-41010,         0).should == '-41 GHz'
      helper.mhz_to_human_size(-41100,         0).should == '-41 GHz'
    end
  end
end
