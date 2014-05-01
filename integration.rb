#encoding: utf-8
require 'csv'

configure do
  RelateIQ.configure(
      {
          :api_key => '53594f98e4b0336349b975cc',
          :api_secret => 'pF932KOSrtuVHielw9mrrohy6zM',
          :base_url => 'https://api.relateiq.com/v2/',
          :version => 'v2'
      }
  )
  Mail.defaults do
    delivery_method :smtp, {
        :port => ENV['MAILGUN_SMTP_PORT'],
        :address => ENV['MAILGUN_SMTP_SERVER'],
        :user_name => ENV['MAILGUN_SMTP_LOGIN'],
        :password => ENV['MAILGUN_SMTP_PASSWORD'],
        :domain => 'fileshare2.herokuapp.com',
        :authentication => :plain,
    }
  end

  #DB = Sequel.connect(ENV["DATABASE_URL"])
  #
  ##schema
  #DB.create_table? :items do
  #  primary_key :id
  #  String :name
  #  Float :amount
  #  Date :date
  #  Date :created_at
  #  String :round
  #  String :csv_content
  #end
  #items = DB[:items]
  #
  #DB.create_table? :imports do
  #  primary_key :id
  #  Date :date
  #  String :csv_content
  #  String :error_message
  #end
  #imports = DB[:imports]
end

before do
  #settings.zendesk_client.config.logger ||= logger
end

get '/' do
  'RelateIQ integration example'
end

post '/' do
  begin
    logger.info params['attachment-1']
    logger.info params['Subject']
    report_name = params['Subject'].gsub('Fwd: Scheduled Report - ', '')
    unless params['attachment-1'] &&
        (tmpfile = params['attachment-1'][:tempfile]) &&
        (name = params['attachment-1'][:filename])
      status 200
    end
    parsed, failed = import_csv(tmpfile.read, '535b4d8fe4b082b80fbf0618')
    success_email(report_name, parsed) if !parsed.empty?
    error_email(failed) if !failed.empty?
    status 201
  rescue => e
    logger.error e
    admin_error_email e
    status 500
  end
end

def create_account_and_list_item(row, list)
  acc = RelateIQ::Account.new
  acc.create(name: row['Company'])

  fields = row.headers.select do |key|
    list.fields.find { |f| f['name'].downcase == key.downcase }
  end.map do |key|
    f = list.fields.find { |f| f['name'].downcase == key.downcase }
    [f['id'], [{'raw' => row[key]}]]
  end
  fields << [0, [{'raw' => 0}]]

  list_attrs = {
      :accountId => acc.id,
      :listId => list.id,
      :name => acc.name,
      :contactIds => [''],
      :fieldValues => Hash[fields]
  }
  RelateIQ.post("lists/#{list.id}/listitems", list_attrs.to_json)

end

def import_csv(scv_string, list_id)
  list = RelateIQ::List.find(list_id)
  failed = []
  parsed = []
  CSV.new(scv_string, :headers => true).each do |row|
    begin
      create_account_and_list_item(row, list)
      parsed << row
    rescue => e
      failed << {company: row['Company'], error: e.message}
    end
  end
  [parsed, failed]
end


def success_email(report_name, rows)
  Mail.deliver do
    #to 'taylor.k.f@gmail.com'
    to 'vic.ivanoff@gmail.com'
    from 'RelateIQ integration robot <integration@domain.com>'
    subject 'Just got one more CBInsights email'
    text_part do
      s = "#{rows.length} companies were successfully added to RelateIQ via CBinsights (#{report_name}) sweep:\n"
      rows.each_with_index do |r, i|
        desc = r['Company Description'].split('.').first if r['Company Description']
        s << "#{r['Company']}"
        s << " - \"#{desc}\"" if desc
        s << "\n  * "
        s << "#{r['Round']}" if r['Round']
        s << " (#{r['Amount']})" if r['Amount']
        s << " with #{r['Investors']}"  if r['Investors']
        s << "\n"
      end
      body s
    end
  end

end

def weekly_email

end

def admin_error_email e
  begin
    Mail.deliver do
      to 'vic.ivanoff@gmail.com'
      from 'RelateIQ integration robot <integration@domain.com>'
      subject 'Something went wrong with the CBInsights email'
      text_part do
        body "Sinatra couldn't process the request, error: #{e.message} \n"
      end
    end
  rescue
    #empty
  end
end

def error_email(errors)
  begin
    Mail.deliver do
      #to 'taylor.k.f@gmail.com'
      to 'vic.ivanoff@gmail.com'
      from 'RelateIQ integration robot <integration@domain.com>'
      subject 'Something went wrong with the CBInsights email'
      text_part do
        s = "RelateIQ API application failed to accept CBinsights CSV. This error was received: \n"
        errors.each do |e|
          s << "Company: #{e[:company]}. Error: #{e[:error]} \n"
        end
        body s
      end
    end
  rescue
    #empty
  end
end
