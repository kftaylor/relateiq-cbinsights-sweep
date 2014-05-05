#encoding: utf-8
require 'csv'
require 'date'
require './company'
require './import'

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

  DB = Sequel.connect(ENV["DATABASE_URL"])
  #
  ##schema

  DB.create_table? :imports do
    primary_key  :id
    String       :report_name
    Date         :date
    String       :csv_content
    String       :error_message
    Date         :created_at
  end

  DB.create_table? :companies do
    primary_key  :id
    String       :report_name
    String       :name
    String       :url
    String       :description
    String       :round
    Float        :amount
    String       :investors
    Date         :date
    Date         :created_at
  end
  companies = DB[:companies]

end

before do
  #settings.zendesk_client.config.logger ||= logger
end

get '/' do
  'RelateIQ integration example'
end

post '/weekly' do
  weekly_email
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
    import = Import.new(report_name, '535b4d8fe4b082b80fbf0618', tmpfile.read)
    parsed, failed = import.process_csv
    success_email(report_name, parsed) if !parsed.empty?
    error_email(failed) if !failed.empty?
    import.to_db
    status 201
  rescue => e
    logger.error e
    admin_error_email e
    status 500
  end
end


def success_email(report_name, companies)
  Mail.deliver do
    to 'taylor.k.f@gmail.com'
    cc 'vic.ivanoff@gmail.com'
    from 'RelateIQ integration robot <integration@domain.com>'
    subject "#{companies.length} relationship(s) added to RelateIQ via CBinsights"
    text_part do
      companies_text = companies.length > 1 ? "#{companies.length} companies were" : "One company was"
      email = "#{companies_text} successfully added to RelateIQ via CBinsights (#{report_name}) sweep:\n"
      companies.each_with_index do |c, i|
        email << c.to_email(i+1)
      end
      body email
    end
  end
end

def weekly_email
  companies = DB[:companies].where{created_at >= (Date.today - 7)}.all.map{|c| Company.from_db c}
  Mail.deliver do
    to 'taylor.k.f@gmail.com'
    cc 'vic.ivanoff@gmail.com'
    from 'RelateIQ integration robot <integration@domain.com>'
    subject 'Weekly RelateIQ email'
    text_part do
      companies_text = companies.length > 1 ? "#{companies.length} companies were" : "one company was"
      email = "This week #{companies_text} successfully added to RelateIQ via CBinsights sweep:\n"
      companies.each_with_index do |c, i|
        email << c.to_email(i+1)
      end
      body email
    end
  end

end

def admin_error_email e
  begin
    Mail.deliver do
      to 'vic.ivanoff@gmail.com'
      to 'taylor.k.f@gmail.com'
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
      to 'taylor.k.f@gmail.com'
      cc 'vic.ivanoff@gmail.com'
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
