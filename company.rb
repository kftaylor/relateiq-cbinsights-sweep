class Company
  attr_accessor   :report_name, :name, :url, :description,
                  :round, :amount, :investors, :date

  def initialize(row = nil)
    parse_row(row) if row
  end

  def parse_row(row)
    @description = row['Company Description'].split('.').first if row['Company Description']
    @name = row['Company']
    @url = row['Company URL']
    self.round = row['Round']
    @amount = (row['Amount'].to_f) if row['Amount'] && !row['Amount'].empty?
    @investors = row['Investors']
    @date = Date.parse(row['Date']) if row['Date'] && !row['Date'].empty?
  end

  def round=(round)
    @round = %w(Angel Seed).find do |r|
      round.downcase.include?(r.downcase)
    end || round
  end

  def to_email(index = nil)
    email = ""
    email << (index ? "#{index}. #{@name}" : @name)
    email << " - \"#{@description}\"" if @description
    email << "\n  * "
    email << @round if round
    email << " ($#{@amount}m)" if @amount > 0
    email << " with investors: #{@investors}" if @investors
    email << "\n"
    email
  end

  def is_too_old?
    @date && (Date.today - @date).to_i > 180
  end


  def relate_iq_fields(list)
    keys = self.instance_variables.map{ |a| a.to_s.downcase.sub('@', '')}
    fields = keys.select do |key|
      list.fields.find { |f| f['name'].downcase == key }
    end.map do |key|
      f = list.fields.find { |f| f['name'].downcase == key }
      [f['id'], [{'raw' => self.send("@#{key}")}]]
    end
    fields << [0, [{'raw' => 0}]]
  end

  def to_db(emails)
    attrs = Hash[ self.instance_variables.map do |ivar|
      [ivar.to_s.sub('@', '').to_sym, self.instance_variable_get(ivar)]
    end
    ]
    emails.insert(attrs)
  end

  def self.from_db(attrs)
    company = self.new
    attrs.delete(:id)
    attrs.each { |k,v| company.send("#{k}=", v) }
    company
  end
end