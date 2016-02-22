describe ActionView::Helpers::NumberHelper do
  context "#number_to_human_size" do
    # Positive cases taken from Rails helper tests for number_to_human_size to
    #   verify that original method's intent was not changed
    #   https://github.com/rails/rails/blob/v2.3.8/actionpack/test/template/number_helper_test.rb
    # Negative cases added from positive cases.

    it "without options hash" do
      expect(helper.number_to_human_size(0)).to eq('0 Bytes')
      expect(helper.number_to_human_size(1)).to eq('1 Byte')
      expect(helper.number_to_human_size(3.14159265)).to eq('3 Bytes')
      expect(helper.number_to_human_size(123.0)).to eq('123 Bytes')
      expect(helper.number_to_human_size(123)).to eq('123 Bytes')
      expect(helper.number_to_human_size(1234)).to eq('1.2 KB')
      expect(helper.number_to_human_size(12_345)).to eq('12.1 KB')
      expect(helper.number_to_human_size(1_234_567)).to eq('1.2 MB')
      expect(helper.number_to_human_size(1_234_567_890)).to eq('1.1 GB')
      expect(helper.number_to_human_size(1_234_567_890_123)).to eq('1.1 TB')
      expect(helper.number_to_human_size(1_234_567_890_123_456)).to eq('1.1 PB')
      expect(helper.number_to_human_size(4.petabytes)).to eq('4 PB')
      expect(helper.number_to_human_size(1022.terabytes)).to eq('1022 TB')
      expect(helper.number_to_human_size(444.kilobytes)).to eq('444 KB')
      expect(helper.number_to_human_size(1023.megabytes)).to eq('1023 MB')
      expect(helper.number_to_human_size(3.terabytes)).to eq('3 TB')
      expect(helper.number_to_human_size("123")).to eq('123 Bytes')
      expect(helper.number_to_human_size(1.1)).to eq('1 Byte')
      expect(helper.number_to_human_size(10)).to eq('10 Bytes')
      expect(helper.number_to_human_size(nil)).to be_nil

      expect(helper.number_to_human_size(-1)).to eq('-1 Byte')
      expect(helper.number_to_human_size(-3.14159265)).to eq('-3 Bytes')
      expect(helper.number_to_human_size(-123.0)).to eq('-123 Bytes')
      expect(helper.number_to_human_size(-123)).to eq('-123 Bytes')
      expect(helper.number_to_human_size(-1234)).to eq('-1.2 KB')
      expect(helper.number_to_human_size(-12_345)).to eq('-12.1 KB')
      expect(helper.number_to_human_size(-1_234_567)).to eq('-1.2 MB')
      expect(helper.number_to_human_size(-1_234_567_890)).to eq('-1.1 GB')
      expect(helper.number_to_human_size(-1_234_567_890_123)).to eq('-1.1 TB')
      expect(helper.number_to_human_size(-1_234_567_890_123_456)).to eq('-1.1 PB')
      expect(helper.number_to_human_size(-4.petabytes)).to eq('-4 PB')
      expect(helper.number_to_human_size(-1022.terabytes)).to eq('-1022 TB')
      expect(helper.number_to_human_size(-444.kilobytes)).to eq('-444 KB')
      expect(helper.number_to_human_size(-1023.megabytes)).to eq('-1023 MB')
      expect(helper.number_to_human_size(-3.terabytes)).to eq('-3 TB')
      expect(helper.number_to_human_size("-123")).to eq('-123 Bytes')
      expect(helper.number_to_human_size(-1.1)).to eq('-1 Byte')
      expect(helper.number_to_human_size(-10)).to eq('-10 Bytes')
    end

    it "with options hash" do
      expect(helper.number_to_human_size(1_234_567,         :precision => 2)).to eq('1.18 MB')
      expect(helper.number_to_human_size(3.14159265,        :precision => 4)).to eq('3 Bytes')
      expect(helper.number_to_human_size(1.0123.kilobytes,  :precision => 2)).to eq('1.01 KB')
      expect(helper.number_to_human_size(1.0100.kilobytes,  :precision => 4)).to eq('1.01 KB')
      expect(helper.number_to_human_size(10.000.kilobytes,  :precision => 4)).to eq('10 KB')
      expect(helper.number_to_human_size(1_234_567_890_123, :precision => 0)).to eq('1 TB')
      expect(helper.number_to_human_size(524_288_000,       :precision => 0)).to eq('500 MB')
      expect(helper.number_to_human_size(41_010,            :precision => 0)).to eq('40 KB')
      expect(helper.number_to_human_size(41_100,            :precision => 0)).to eq('40 KB')

      expect(helper.number_to_human_size(-1_234_567,         :precision => 2)).to eq('-1.18 MB')
      expect(helper.number_to_human_size(-3.14159265,        :precision => 4)).to eq('-3 Bytes')
      expect(helper.number_to_human_size(-1.0123.kilobytes,  :precision => 2)).to eq('-1.01 KB')
      expect(helper.number_to_human_size(-1.0100.kilobytes,  :precision => 4)).to eq('-1.01 KB')
      expect(helper.number_to_human_size(-10.000.kilobytes,  :precision => 4)).to eq('-10 KB')
      expect(helper.number_to_human_size(-1_234_567_890_123, :precision => 0)).to eq('-1 TB')
      expect(helper.number_to_human_size(-524_288_000,       :precision => 0)).to eq('-500 MB')
      expect(helper.number_to_human_size(-41_010,             :precision => 0)).to eq('-40 KB')
      expect(helper.number_to_human_size(-41_100,             :precision => 0)).to eq('-40 KB')
    end

    it "with custom delimiter and separator" do
      expect(helper.number_to_human_size(1.0123.kilobytes,  :precision => 2,   :separator => ',')).to eq('1,01 KB')
      expect(helper.number_to_human_size(1.0100.kilobytes,  :precision => 4,   :separator => ',')).to eq('1,01 KB')
      expect(helper.number_to_human_size(1000.1.terabytes,  :delimiter => '.', :separator => ',')).to eq('1.000,1 TB')

      expect(helper.number_to_human_size(-1.0123.kilobytes, :precision => 2,   :separator => ',')).to eq('-1,01 KB')
      expect(helper.number_to_human_size(-1.0100.kilobytes, :precision => 4,   :separator => ',')).to eq('-1,01 KB')
      expect(helper.number_to_human_size(-1000.1.terabytes, :delimiter => '.', :separator => ',')).to eq('-1.000,1 TB')
    end
  end

  it "#human_size_to_rails_method" do
    expect(helper.human_size_to_rails_method('0 Bytes')).to eq('0')
    expect(helper.human_size_to_rails_method('1 Byte')).to eq('1')
    expect(helper.human_size_to_rails_method('123 Bytes')).to eq('123')
    expect(helper.human_size_to_rails_method('444 KB')).to eq('444.kilobytes')
    expect(helper.human_size_to_rails_method('1023 MB')).to eq('1023.megabytes')
    expect(helper.human_size_to_rails_method('123 GB')).to eq('123.gigabytes')
    expect(helper.human_size_to_rails_method('1022 TB')).to eq('1022.terabytes')
    expect(helper.human_size_to_rails_method('4 PB')).to eq('4.petabytes')
    expect(helper.human_size_to_rails_method('123.4 Bytes')).to eq('123.4')
    expect(helper.human_size_to_rails_method('12.1 KB')).to eq('12.1.kilobytes')
    expect(helper.human_size_to_rails_method('1.2 MB')).to eq('1.2.megabytes')
    expect(helper.human_size_to_rails_method('1.1 GB')).to eq('1.1.gigabytes')
    expect(helper.human_size_to_rails_method('1.1 TB')).to eq('1.1.terabytes')

    expect(helper.human_size_to_rails_method('-1 Byte')).to eq('-1')
    expect(helper.human_size_to_rails_method('-123 Bytes')).to eq('-123')
    expect(helper.human_size_to_rails_method('-444 KB')).to eq('-444.kilobytes')
    expect(helper.human_size_to_rails_method('-1023 MB')).to eq('-1023.megabytes')
    expect(helper.human_size_to_rails_method('-123 GB')).to eq('-123.gigabytes')
    expect(helper.human_size_to_rails_method('-1022 TB')).to eq('-1022.terabytes')
    expect(helper.human_size_to_rails_method('-4 PB')).to eq('-4.petabytes')
    expect(helper.human_size_to_rails_method('-123.4 Bytes')).to eq('-123.4')
    expect(helper.human_size_to_rails_method('-12.1 KB')).to eq('-12.1.kilobytes')
    expect(helper.human_size_to_rails_method('-1.2 MB')).to eq('-1.2.megabytes')
    expect(helper.human_size_to_rails_method('-1.1 GB')).to eq('-1.1.gigabytes')
    expect(helper.human_size_to_rails_method('-1.1 TB')).to eq('-1.1.terabytes')
  end

  it "#number_to_rails_method" do
    expect(helper.number_to_rails_method(0)).to eq('0')
    expect(helper.number_to_rails_method(1)).to eq('1')
    expect(helper.number_to_rails_method(3.14159265)).to eq('3')
    expect(helper.number_to_rails_method(123.0)).to eq('123')
    expect(helper.number_to_rails_method(123)).to eq('123')
    expect(helper.number_to_rails_method(1234)).to eq('1.2.kilobytes')
    expect(helper.number_to_rails_method(12_345)).to eq('12.1.kilobytes')
    expect(helper.number_to_rails_method(1_234_567)).to eq('1.2.megabytes')
    expect(helper.number_to_rails_method(1_234_567_890)).to eq('1.1.gigabytes')
    expect(helper.number_to_rails_method(1_234_567_890_123)).to eq('1.1.terabytes')
    expect(helper.number_to_rails_method(1_234_567_890_123_456)).to eq('1.1.petabytes')
    expect(helper.number_to_rails_method(4.petabytes)).to eq('4.petabytes')
    expect(helper.number_to_rails_method(1022.terabytes)).to eq('1022.terabytes')
    expect(helper.number_to_rails_method(444.kilobytes)).to eq('444.kilobytes')
    expect(helper.number_to_rails_method(1023.megabytes)).to eq('1023.megabytes')
    expect(helper.number_to_rails_method(3.terabytes)).to eq('3.terabytes')
    expect(helper.number_to_rails_method("123")).to eq('123')
    expect(helper.number_to_rails_method(1.1)).to eq('1')
    expect(helper.number_to_rails_method(10)).to eq('10')
    expect(helper.number_to_rails_method(nil)).to be_nil

    expect(helper.number_to_rails_method(-1)).to eq('-1')
    expect(helper.number_to_rails_method(-3.14159265)).to eq('-3')
    expect(helper.number_to_rails_method(-123.0)).to eq('-123')
    expect(helper.number_to_rails_method(-123)).to eq('-123')
    expect(helper.number_to_rails_method(-1234)).to eq('-1.2.kilobytes')
    expect(helper.number_to_rails_method(-12_345)).to eq('-12.1.kilobytes')
    expect(helper.number_to_rails_method(-1_234_567)).to eq('-1.2.megabytes')
    expect(helper.number_to_rails_method(-1_234_567_890)).to eq('-1.1.gigabytes')
    expect(helper.number_to_rails_method(-1_234_567_890_123)).to eq('-1.1.terabytes')
    expect(helper.number_to_rails_method(-1_234_567_890_123_456)).to eq('-1.1.petabytes')
    expect(helper.number_to_rails_method(-4.petabytes)).to eq('-4.petabytes')
    expect(helper.number_to_rails_method(-1022.terabytes)).to eq('-1022.terabytes')
    expect(helper.number_to_rails_method(-444.kilobytes)).to eq('-444.kilobytes')
    expect(helper.number_to_rails_method(-1023.megabytes)).to eq('-1023.megabytes')
    expect(helper.number_to_rails_method(-3.terabytes)).to eq('-3.terabytes')
    expect(helper.number_to_rails_method("-123")).to eq('-123')
    expect(helper.number_to_rails_method(-1.1)).to eq('-1')
    expect(helper.number_to_rails_method(-10)).to eq('-10')
  end

  it "#human_size_to_number" do
    expect(helper.human_size_to_number('0 Bytes')).to eq(0)
    expect(helper.human_size_to_number('1 Byte')).to eq(1)
    expect(helper.human_size_to_number('123 Bytes')).to eq(123)
    expect(helper.human_size_to_number('444 KB')).to eq(444.kilobytes)
    expect(helper.human_size_to_number('1023 MB')).to eq(1023.megabytes)
    expect(helper.human_size_to_number('123 GB')).to eq(123.gigabytes)
    expect(helper.human_size_to_number('1022 TB')).to eq(1022.terabytes)
    expect(helper.human_size_to_number('4 PB')).to eq(4.petabytes)
    expect(helper.human_size_to_number('123.4 Bytes')).to eq(123.4)
    expect(helper.human_size_to_number('12.1 KB')).to eq(12.1.kilobytes)
    expect(helper.human_size_to_number('1.2 MB')).to eq(1.2.megabytes)
    expect(helper.human_size_to_number('1.1 GB')).to eq(1.1.gigabytes)
    expect(helper.human_size_to_number('1.1 TB')).to eq(1.1.terabytes)

    expect(helper.human_size_to_number('-1 Byte')).to eq(-1)
    expect(helper.human_size_to_number('-123 Bytes')).to eq(-123)
    expect(helper.human_size_to_number('-444 KB')).to eq(-444.kilobytes)
    expect(helper.human_size_to_number('-1023 MB')).to eq(-1023.megabytes)
    expect(helper.human_size_to_number('-123 GB')).to eq(-123.gigabytes)
    expect(helper.human_size_to_number('-1022 TB')).to eq(-1022.terabytes)
    expect(helper.human_size_to_number('-4 PB')).to eq(-4.petabytes)
    expect(helper.human_size_to_number('-123.4 Bytes')).to eq(-123.4)
    expect(helper.human_size_to_number('-12.1 KB')).to eq(-12.1.kilobytes)
    expect(helper.human_size_to_number('-1.2 MB')).to eq(-1.2.megabytes)
    expect(helper.human_size_to_number('-1.1 GB')).to eq(-1.1.gigabytes)
    expect(helper.human_size_to_number('-1.1 TB')).to eq(-1.1.terabytes)
  end

  it "#rails_method_to_human_size" do
    expect(helper.rails_method_to_human_size('0')).to eq('0 Bytes')
    expect(helper.rails_method_to_human_size('1')).to eq('1 Byte')
    expect(helper.rails_method_to_human_size('123')).to eq('123 Bytes')
    expect(helper.rails_method_to_human_size('0.bytes')).to eq('0 Bytes')
    expect(helper.rails_method_to_human_size('1.bytes')).to eq('1 Byte')
    expect(helper.rails_method_to_human_size('123.bytes')).to eq('123 Bytes')
    expect(helper.rails_method_to_human_size('444.kilobytes')).to eq('444 KB')
    expect(helper.rails_method_to_human_size('1023.megabytes')).to eq('1023 MB')
    expect(helper.rails_method_to_human_size('123.gigabytes')).to eq('123 GB')
    expect(helper.rails_method_to_human_size('1022.terabytes')).to eq('1022 TB')
    expect(helper.rails_method_to_human_size('4.petabytes')).to eq('4 PB')
    expect(helper.rails_method_to_human_size('123.4')).to eq('123 Bytes') # rounds bytes
    expect(helper.rails_method_to_human_size('123.4.bytes')).to eq('123 Bytes') # rounds bytes
    expect(helper.rails_method_to_human_size('12.1.kilobytes')).to eq('12.1 KB')
    expect(helper.rails_method_to_human_size('1.2.megabytes')).to eq('1.2 MB')
    expect(helper.rails_method_to_human_size('1.1.gigabytes')).to eq('1.1 GB')
    expect(helper.rails_method_to_human_size('1.1.terabytes')).to eq('1.1 TB')

    expect(helper.rails_method_to_human_size('-1')).to eq('-1 Byte')
    expect(helper.rails_method_to_human_size('-123')).to eq('-123 Bytes')
    expect(helper.rails_method_to_human_size('-1.bytes')).to eq('-1 Byte')
    expect(helper.rails_method_to_human_size('-123.bytes')).to eq('-123 Bytes')
    expect(helper.rails_method_to_human_size('-444.kilobytes')).to eq('-444 KB')
    expect(helper.rails_method_to_human_size('-1023.megabytes')).to eq('-1023 MB')
    expect(helper.rails_method_to_human_size('-123.gigabytes')).to eq('-123 GB')
    expect(helper.rails_method_to_human_size('-1022.terabytes')).to eq('-1022 TB')
    expect(helper.rails_method_to_human_size('-4.petabytes')).to eq('-4 PB')
    expect(helper.rails_method_to_human_size('-123.4')).to eq('-123 Bytes') # rounds bytes
    expect(helper.rails_method_to_human_size('-123.4.bytes')).to eq('-123 Bytes') # rounds bytes
    expect(helper.rails_method_to_human_size('-12.1.kilobytes')).to eq('-12.1 KB')
    expect(helper.rails_method_to_human_size('-1.2.megabytes')).to eq('-1.2 MB')
    expect(helper.rails_method_to_human_size('-1.1.gigabytes')).to eq('-1.1 GB')
    expect(helper.rails_method_to_human_size('-1.1.terabytes')).to eq('-1.1 TB')
  end

  context "#mhz_to_human_size" do
    it "without options hash" do
      expect(helper.mhz_to_human_size(0)).to eq('0 MHz')
      expect(helper.mhz_to_human_size(1)).to eq('1 MHz')
      expect(helper.mhz_to_human_size(3.14159265)).to eq('3.1 MHz')
      expect(helper.mhz_to_human_size(123.0)).to eq('123 MHz')
      expect(helper.mhz_to_human_size(123)).to eq('123 MHz')
      expect(helper.mhz_to_human_size(1234)).to eq('1.2 GHz')
      expect(helper.mhz_to_human_size(12_345)).to eq('12.3 GHz')
      expect(helper.mhz_to_human_size(1_234_567)).to eq('1.2 THz')
      expect(helper.mhz_to_human_size(1_234_567_890)).to eq('1234.6 THz')
      expect(helper.mhz_to_human_size(1_234_567_890_123)).to eq('1234567.9 THz')
      expect(helper.mhz_to_human_size("123")).to eq('123 MHz')
      expect(helper.mhz_to_human_size(nil)).to be_nil

      expect(helper.mhz_to_human_size(-1)).to eq('-1 MHz')
      expect(helper.mhz_to_human_size(-3.14159265)).to eq('-3.1 MHz')
      expect(helper.mhz_to_human_size(-123.0)).to eq('-123 MHz')
      expect(helper.mhz_to_human_size(-123)).to eq('-123 MHz')
      expect(helper.mhz_to_human_size(-1234)).to eq('-1.2 GHz')
      expect(helper.mhz_to_human_size(-12_345)).to eq('-12.3 GHz')
      expect(helper.mhz_to_human_size(-1_234_567)).to eq('-1.2 THz')
      expect(helper.mhz_to_human_size(-1_234_567_890)).to eq('-1234.6 THz')
      expect(helper.mhz_to_human_size(-1_234_567_890_123)).to eq('-1234567.9 THz')
      expect(helper.mhz_to_human_size("-123")).to eq('-123 MHz')
    end

    it "with options hash" do
      expect(helper.mhz_to_human_size(1_234_567,         :precision => 2)).to eq('1.23 THz')
      expect(helper.mhz_to_human_size(3.14159265,        :precision => 4)).to eq('3.1416 MHz')
      expect(helper.mhz_to_human_size(1_234_567_890_123, :precision => 0)).to eq('1234568 THz')
      expect(helper.mhz_to_human_size(524_288_000,       :precision => 0)).to eq('524 THz')
      expect(helper.mhz_to_human_size(41_010,            :precision => 0)).to eq('41 GHz')
      expect(helper.mhz_to_human_size(41_100,            :precision => 0)).to eq('41 GHz')

      expect(helper.mhz_to_human_size(-1_234_567,         :precision => 2)).to eq('-1.23 THz')
      expect(helper.mhz_to_human_size(-3.14159265,        :precision => 4)).to eq('-3.1416 MHz')
      expect(helper.mhz_to_human_size(-1_234_567_890_123, :precision => 0)).to eq('-1234568 THz')
      expect(helper.mhz_to_human_size(-524_288_000,       :precision => 0)).to eq('-524 THz')
      expect(helper.mhz_to_human_size(-41_010,            :precision => 0)).to eq('-41 GHz')
      expect(helper.mhz_to_human_size(-41_100,            :precision => 0)).to eq('-41 GHz')
    end

    it "with old precision argument" do
      expect(helper.mhz_to_human_size(1_234_567, 2)).to eq('1.23 THz')
      expect(helper.mhz_to_human_size(3.14159265, 4)).to eq('3.1416 MHz')
      expect(helper.mhz_to_human_size(1_234_567_890_123, 0)).to eq('1234568 THz')
      expect(helper.mhz_to_human_size(524_288_000, 0)).to eq('524 THz')
      expect(helper.mhz_to_human_size(41_010, 0)).to eq('41 GHz')
      expect(helper.mhz_to_human_size(41_100, 0)).to eq('41 GHz')

      expect(helper.mhz_to_human_size(-1_234_567, 2)).to eq('-1.23 THz')
      expect(helper.mhz_to_human_size(-3.14159265, 4)).to eq('-3.1416 MHz')
      expect(helper.mhz_to_human_size(-1_234_567_890_123, 0)).to eq('-1234568 THz')
      expect(helper.mhz_to_human_size(-524_288_000, 0)).to eq('-524 THz')
      expect(helper.mhz_to_human_size(-41_010, 0)).to eq('-41 GHz')
      expect(helper.mhz_to_human_size(-41_100, 0)).to eq('-41 GHz')
    end
  end
end
