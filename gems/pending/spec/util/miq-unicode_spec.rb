require "spec_helper"
require 'util/miq-unicode'

describe 'miq-unicode' do
  context "with Unicode and UTF-8 data" do
    before(:each) do
      @unicode_str = "S\000Y\000S\000T\000E\000M\000\000\000\000\000\000\000"
      @utf8_str    = "SYSTEM\000\000\000"

      @unicode_str.force_encoding("UTF-16LE")
      @utf8_str.force_encoding("UTF-8")
    end

    it '.UnicodeToUtf8' do
      converted_utf8 = @unicode_str.UnicodeToUtf8
      expect(converted_utf8.object_id).not_to eq(@unicode_str.object_id)
      expect(converted_utf8).to eq(@utf8_str)
    end

    it '.UnicodeToUtf8!' do
      converted_utf8 = @unicode_str.UnicodeToUtf8!
      expect(converted_utf8.object_id).to eq(@unicode_str.object_id)
      expect(converted_utf8).to eq(@utf8_str)
    end

    it '.Utf8ToUnicode' do
      converted_unicode = @utf8_str.Utf8ToUnicode
      expect(converted_unicode.object_id).not_to eq(@utf8_str.object_id)
      expect(converted_unicode).to eq(@unicode_str)
    end

    it '.Utf8ToUnicode!' do
      converted_unicode = @utf8_str.Utf8ToUnicode!
      expect(converted_unicode.object_id).to eq(@utf8_str.object_id)
      expect(converted_unicode).to eq(@unicode_str)
    end
  end

  context "with UTF-8 and ASCII data" do
    before(:each) do
      @utf8_str  = "123\303\245456"
      @ascii_str = "123\345456"

      @utf8_str.force_encoding("UTF-8")
      @ascii_str.force_encoding("ISO-8859-1")
    end

    it '.AsciiToUtf8' do
      converted_utf8 = @ascii_str.AsciiToUtf8
      expect(converted_utf8.object_id).not_to eq(@ascii_str.object_id)
      expect(converted_utf8).to eq(@utf8_str)
    end

    it '.AsciiToUtf8!' do
      converted_utf8 = @ascii_str.AsciiToUtf8!
      expect(converted_utf8.object_id).to eq(@ascii_str.object_id)
      expect(converted_utf8).to eq(@utf8_str)
    end

    it '.Utf8ToAscii' do
      converted_ascii = @utf8_str.Utf8ToAscii
      expect(converted_ascii.object_id).not_to eq(@utf8_str.object_id)
      expect(converted_ascii).to eq(@ascii_str)
    end

    it '.Utf8ToAscii!' do
      converted_ascii = @utf8_str.Utf8ToAscii!
      expect(converted_ascii.object_id).to eq(@utf8_str.object_id)
      expect(converted_ascii).to eq(@ascii_str)
    end
  end

  context "with ASCII and UCS-2 data" do
    before(:each) do
      @ucs2_str  = "1\000.\0008\000.\0007\000"
      @ascii_str = "1.8.7"

      @ucs2_str.force_encoding("UTF-16LE")
      @ascii_str.force_encoding("ISO-8859-1")
    end

    it '.Ucs2ToAscii' do
      converted_ascii = @ucs2_str.Ucs2ToAscii
      expect(converted_ascii.object_id).not_to eq(@ucs2_str.object_id)
      expect(converted_ascii).to eq(@ascii_str)
    end

    it '.Ucs2ToAscii!' do
      converted_ascii = @ucs2_str.Ucs2ToAscii!
      expect(converted_ascii.object_id).to eq(@ucs2_str.object_id)
      expect(converted_ascii).to eq(@ascii_str)
    end
  end
end
