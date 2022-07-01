class BP::Archive
  attr_reader :name, :date

  def initialize(raw_name)
    @raw_name = raw_name
    s = StringScanner.new(raw_name)
    @date = Date.parse(s.scan(/\d{4}-\d{2}-\d{2}/))
    s.skip(/_/)
    @name = s.scan(/.+\z/)
  end
end
