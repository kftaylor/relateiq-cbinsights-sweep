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
  'RelateIQ integration example'
end

post '/' do
  begin
    logger.info params['attachment-1']
    unless params['attachment-1'] &&
        (tmpfile = params['attachment-1'][:tempfile]) &&
        (name = params['attachment-1'][:filename])
      status 200
    end

    list = RelateIQ::List.find('535b4d8fe4b082b80fbf0618')
    list_id = '535b4d8fe4b082b80fbf0618'

    CSV.new(tmpfile.read, :headers => true).each do |row|
      acc = RelateIQ::Account.new
      acc.create(name: row['Company'])

      fields = row.headers.select do |key|
        list.fields.find {|f| f['name'].downcase == key.downcase}
      end.map do |key|
        f = list.fields.find {|f| f['name'].downcase == key.downcase}
        [f['id'], ['raw' => row[key]]]
      end

      list_attrs = {
          :accountId => acc.id,
          :name => acc.name,
          :contactIds => [''],
          :fields => Hash[fields]
      }
      RelateIQ.post("lists/#{list_id}/listitems", list_attrs.to_json)
    end

    status 201
  rescue => e
    logger.error e
    status 500
  end
end

