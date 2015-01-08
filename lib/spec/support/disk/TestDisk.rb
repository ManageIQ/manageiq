module TestDisk
	def d_init
    @blockSize = 512
  end

	def d_read(pos, len, offset = 0)
    return "\0" * 5
  end

  def d_write(pos, buf, len, offset = 0)
  end

  def d_close
  end

  def d_size
    100
  end
end
