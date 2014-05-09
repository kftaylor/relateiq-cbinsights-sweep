class Company
  attr_accessor   :name, :data, :date, :created_at

  def initialize(row = nil)
    @data = Hash.new
    parse_row(row) if row
  end

  def parse_row(row)
    @name = row['Company']
    @date = Date.parse(row['Date']) if row['Date'] && !row['Date'].empty?
    @created_at = Date.today
    row.each do |pair|
      @data[pair.first.downcase] = pair.last
    end
    @data['round'] = preprocess_round(@data['round'])
    @data['description'] = @data['company description']
  end

  def get(key)
    @data[key]
  end

  def preprocess_round(round)
    %w(Angel Seed).find do |r|
      round.downcase.include?(r.downcase)
    end || round
  end

  def to_email(index = nil)
    email = ""
    email << (index ? "#{index}. #{@name}" : @name)
    email << " (#{url})" if url
    email << " - \"#{company_description}\"" if company_description
    email << "\n   "
    email << round if (round && !round.empty?)
    email << " ($#{amount}m)" if (amount && amount.to_f > 0)
    email << " with investors: #{investors.split(';').join(', ')}" if investors
    email << ". Funding date: #{@date}" if self.is_too_old?
    email << "\n"
    email
  end

  def is_too_old?
    @date && (Date.today - @date).to_i > 180
  end


  def relate_iq_fields(list)
    keys = @data.keys
    fields = keys.select do |key|
      list.fields.find { |f| f['name'].downcase == key }
    end.map do |key|
      f = list.fields.find { |f| f['name'].downcase == key }
      [f['id'], [{'raw' => @data[key.to_s]}]]
    end
    fields << [0, [{'raw' => 0}]]
  end

  def to_db(emails)
    attrs = {
        :name => @name,
        :created_at => @created_at,
        :date => @date,
        :data => Sequel.hstore(@data)
    }
    emails.insert(attrs)
  end

  def self.from_db(attrs)
    company = self.new
    %w(name date created_at data).each {|attr| company.send(attr+'=', attrs[attr.to_sym])}
    company
  end

  def method_missing(method, *args, &block)
    return @data[method.to_s] if @data[method.to_s]
    key = method.to_s.split('_').join(' ')
    return @data[key] if @data[key]
    super
  end
end