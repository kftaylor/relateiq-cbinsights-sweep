#encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'json'
require 'logger'
require 'relateiq'
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
end

before do
  #settings.zendesk_client.config.logger ||= logger
end

get '/' do
  'CopperEgg Webhook Handler Example'
end

post '/' do
  begin
    logger.info params['attachment-1']
    unless params['attachment-1'] &&
        (tmpfile = params['attachment-1'][:tempfile]) &&
        (name = params['attachment-1'][:filename])
      @error = "No file selected"
    end
    s = tmpfile.read
    #STDERR.puts s
    CSV.new(s, :headers => true).each do |row|
      STDERR.puts row.inspect
      c = RelateIQ::Account.new
      c.create(name: row['Company'])

    end

    status 201
  rescue => e
    logger.error e
    status 500
  end
end


