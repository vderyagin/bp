# typed: true
# frozen_string_literal: true

require 'date'
require 'strscan'

class BP::Archive
  attr_reader :name, :date

  def initialize(raw_name)
    @raw_name = raw_name
    s = StringScanner.new(raw_name)
    @date = Date.parse(s.scan(/\d{4}-\d{2}-\d{2}/))
    s.skip(/_/)
    @name = s.scan(/.+\z/)
  end

  def drop_cmd
    %W[tarsnap -d -f #{@raw_name}]
  end

  def extract_cmd
    %W[tarsnap -x -f #{@raw_name}]
  end
end
