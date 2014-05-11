class ImportResult
  attr_accessor :parsed, :failed, :too_old, :already_exists

  def initialize(parsed = nil, failed = nil, too_old = nil, already_exists = nil)
    @parsed = parsed || []
    @failed = failed || []
    @too_old = too_old || []
    @already_exists = already_exists || []
  end

  def errors?
    !@failed.empty?
  end

  def success?
    !@parsed.empty?
  end

end