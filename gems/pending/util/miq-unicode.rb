class String
  # See Programming Ruby 1.9 - The Pragmatic Programmers’ Guide
  # Figure 17.1. "Encodings and Their Aliases" in the for available encodings.
  def UnicodeToUtf8
    dup.force_encoding("UTF-16LE").encode("UTF-8")
  end

  def UnicodeToUtf8!
    force_encoding("UTF-16LE").encode!("UTF-8")
  end

  def Utf8ToUnicode
    dup.force_encoding("UTF-8").encode("UTF-16LE")
  end

  def Utf8ToUnicode!
    force_encoding("UTF-8").encode!("UTF-16LE")
  end

  def AsciiToUtf8
    dup.force_encoding("ISO-8859-1").encode("UTF-8")
  end

  def AsciiToUtf8!
    force_encoding("ISO-8859-1").encode!("UTF-8")
  end

  def Utf8ToAscii
    dup.force_encoding("UTF-8").encode("ISO-8859-1")
  end

  def Utf8ToAscii!
    force_encoding("UTF-8").encode!("ISO-8859-1")
  end

  def Ucs2ToAscii
    dup.force_encoding("UTF-16LE").encode("ISO-8859-1")
  end

  def Ucs2ToAscii!
    force_encoding("UTF-16LE").encode!("ISO-8859-1")
  end
end
