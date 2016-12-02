require 'sinatra'
require 'intercom'
require 'thin'
require 'json'
require "net/http"
require "uri"

class MyThinBackend < ::Thin::Backends::TcpServer
  def initialize(host, port, options)
    super(host, port)
    @ssl = true
    @ssl_options = options
  end
end

configure do
  set :environment, :production
  set :bind, '0.0.0.0'
  #:set :port, 443
  set :server, "thin"
  enable :sessions
  class << settings
    def server_settings
      {
          :backend          => MyThinBackend,
          :private_key_file => File.dirname(__FILE__) + "/pkey.pem",
          :cert_chain_file  => File.dirname(__FILE__) + "/cert.crt",
          :verify_peer      => false
      }
    end
  end
end

get '/auth/callback' do
  #Get the Code passed back to our redirect callback
  @code = params[:code]
  @state = params[:state]
  puts "CODE: #{@code}"
  puts "STATE:#{@state}"

  #We can do a Post now to get the access token
  uri = URI.parse("https://api.intercom.io/auth/eagle/token")
  response = Net::HTTP.post_form(uri, {"code" => params[:code],
                                       "client_id" => "",
                                       "client_secret" => ""})

  #Break Up the response and print out the Access Token
  rsp = JSON.parse(response.body)
  session[:token] = rsp["token"]
  redirect '/'
end

get '/' do
  erb :index
end

get '/users' do 
	erb :"users/index"
end

get '/users/:id' do
	init_intercom
	find_user_by_intercom_id
	erb :"users/show"
end

get '/users/:id/edit' do
	init_intercom
	@id = params[:id]
	find_user_by_intercom_id
	erb :"users/edit"
end

post '/users/new' do
	init_intercom
	@user = @intercom.users.create(:email => params[:email])
	redirect "/users/#{@user.id}"
end

post '/users/update' do
	init_intercom
	find_user_by_intercom_id
	@user.email = params[:user_email]
	@intercom.users.save(@user)
	redirect '/users/'+@user.id
end

post '/users/search' do
	init_intercom
	find_user_by_intercom_id
	redirect '/users/'+@user.id
end

def init_intercom
	@intercom = Intercom::Client.new(token: "#{session[:token]}")
end

def find_user_by_intercom_id
	@user = @intercom.users.find(:id => params[:id])
end