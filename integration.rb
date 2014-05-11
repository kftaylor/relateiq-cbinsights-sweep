#encoding: utf-8
require 'csv'
require 'date'
require 'erb'
require './company'
require './import'
require './import_result'
require 'sequel/extensions/pg_hstore'


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
        :authentication => :plain,
    }
  end
  Sequel.extension(:pg_hstore, :pg_hstore_ops, :pg_array)
  DB = Sequel.connect(ENV['DATABASE_URL'])
  #
  ##schema

  DB.create_table? :imports do
    primary_key :id
    String :report_name
    Date :date
    String :csv_content
    String :error_message
    Date :created_at
  end

  DB.create_table? :companies do
    primary_key :id
    String :name
    Date :date
    Date :created_at
    HStore :data
  end
end

before do
  # do something before every request
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
    import_result = import.process_csv
    success_email(report_name, import_result) if import_result.should_send_success_email?
    error_email(import_result) if import_result.should_send_error_email?
    import.to_db
    status 201
  rescue => e
    logger.error e
    admin_error_email e
    status 500
  end
end


def success_email(report_name, import_result)
  companies = import_result.parsed
  Mail.deliver do
    to 'taylor.k.f@gmail.com'
    cc 'vic.ivanoff@gmail.com'
    from 'RelateIQ Robot <integration@relateiq-cbinsights-sweep.herokuapp.com>'
    subject "#{companies.length} relationship(s) added to RelateIQ via CBInsights"
    text_part do
      email = ''
      if companies.length > 0
        companies_text = companies.length > 1 ? "#{companies.length} companies were" : 'One company was'
        email = "#{companies_text} successfully added to RelateIQ via CBInsights (#{report_name}) sweep:\n"
        companies.each_with_index do |c, i|
          email << c.to_email(i+1)
        end
        email << "\n"
      end
      if import_result.too_old.length > 0
        too_old = import_result.too_old
        deals = too_old.length == 1 ? '1 deal was' : "#{too_old.length} deals were"
        email << "#{deals} excluded due to a funding date:\n"
        too_old.each_with_index do |company, i|
          email << company.to_email(i+1)
        end
        email << "\n"
      end
      if import_result.already_exists.length > 0
        already_exists = import_result.already_exists
        already_exists_text = already_exists.length == 1 ? 'one' : "#{already_exists.length} deals were"
        email << "#{already_exists_text} companies excluded due to existing relationship in RelateIQ."
      end
      body email
    end
    html_part do
      layout = Tilt.new('layout.erb')
      email_partial = Tilt.new('email.erb')
      html = layout.render do
        email_partial.render(nil, import_result: import_result, report_name: report_name)
      end
      body html
    end
  end
end

def weekly_email
  companies = DB[:companies].where { created_at >= (Date.today - 7) }.all.map { |c| Company.from_db c }
  Mail.deliver do
    to 'taylor.k.f@gmail.com'
    cc 'vic.ivanoff@gmail.com'
    from 'RelateIQ Robot <integration@relateiq-cbinsights-sweep.herokuapp.com>'
    subject 'Weekly RelateIQ email'
    text_part do
      companies_text = companies.length > 1 ? "#{companies.length} companies were" : 'one company was'
      email = "This week #{companies_text} successfully added to RelateIQ via CBinsights sweep:\n"
      companies.each_with_index do |c, i|
        email << c.to_email(i+1)
      end
      body email
    end
    html_part do
      layout = Tilt.new('layout.erb')
      weekly_email_partial = Tilt.new('weekly_email.erb')
      html = layout.render do
        weekly_email_partial.render(nil, companies: companies)
      end
      body html
    end
  end
end

def admin_error_email(e)
  begin
    logger.error e.message
    Mail.deliver do
      to 'vic.ivanoff@gmail.com'
      from 'RelateIQ Robot <integration@relateiq-cbinsights-sweep.herokuapp.com>'
      subject 'Something went wrong with the CBInsights email'
      text_part do
        body "Sinatra couldn't process the request, error: #{e.message} \n"
      end
    end
  rescue => error
    logger.error error.message
  end
end

def error_email(import_result)
  begin
    Mail.deliver do
      to 'taylor.k.f@gmail.com'
      cc 'vic.ivanoff@gmail.com'
      from 'RelateIQ Robot <integration@relateiq-cbinsights-sweep.herokuapp.com>'
      subject 'Something went wrong with the CBInsights email'
      text_part do
        email = "RelateIQ API application failed to accept CBInsights CSV. This error was received: \n"
        import_result.failed.each do |e|
          email << "Company: #{e[:company]}. Error: #{e[:error]} \n"
        end
        body email
      end
    end
  rescue => error
    logger.error error.message
  end
end
