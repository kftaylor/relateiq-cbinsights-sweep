$stdout.sync = true
require 'rubygems'
require 'bundler'

Bundler.require

require './integration'
run Sinatra::Application
