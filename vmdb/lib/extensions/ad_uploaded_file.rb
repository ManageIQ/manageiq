# Delegate methods to Tempfile.  These can be removed once fixed:
# https://github.com/rails/rails/pull/2664
# http://marklunds.com/articles/one/433
class ActionDispatch::Http::UploadedFile
  def close
    @tempfile.close
  end

  def eof?
    @tempfile.eof?
  end

  def eof
    @tempfile.eof
  end
end
