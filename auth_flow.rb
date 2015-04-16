require 'rubygems'
require 'bundler/setup'
require 'sinatra/base'
require 'faraday'
require 'faraday_middleware'
require 'json'
require 'base64'
require 'open-uri'

class Callback < Sinatra::Base

  enable :sessions

  before do
    @endpoint ='http://localhost:7070/heimdall'
    #@endpoint ='http://localhost:8080/auth'

    @access_token_path = 'oauth/token'
    @auth_path='oauth/authorize'

    @client_id = 'my_app'
    @client_secret = 'passwd'
    @redirect_uri = 'http://localhost:4567/callback'
    @redirect_implict = 'http://localhost:4567/implicit_call'

    #@granted_scopes=['read', 'write'].join('+')
    @granted_scopes='read'

    #content_type :json
  end

  get '/callback' do
    get_token(params['code'])
  end


  get '/implicit_call' do
    erb :page
  end


  get '/hello' do
    "Hello world"
  end

  def get_token(code)

    client_app_credentials = "#{@client_id}:#{@client_secret}"
    hash_credentials = Base64.encode64(client_app_credentials)
    enconde_auth = "Basic #{hash_credentials.strip}"

    conn = Faraday.new(url: @endpoint) do |c|
      c.request  :url_encoded
      c.adapter Faraday.default_adapter
    end

    #res = conn.get @access_token_path do |req|
    #  req.params['code'] = code
    #  req.params['client_id'] = @client_id
    #  req.params['redirect_uri'] = @redirect_uri
    #  req.params['grant_type'] = 'authorization_code'

    #  req.headers['Authorization'] = enconde_auth
    #end

    res = conn.post do |req|
      req.url @access_token_path
      req.headers['Authorization'] = enconde_auth

      req.body = { :code => code, :client_id => @client_id, :redirect_uri => @redirect_uri, :grant_type => 'authorization_code' }
    end

    parse_response(res)
    res.body
  end

  def parse_response(res)
    begin
      response = JSON.parse(res.body)

      session[:access_token] = response['access_token']
      session[:token_type] = response['token_type']
      session[:expires] = response['expires_in']
      session[:scope] = response['scope']
    rescue Exception => e
      puts e
      puts res.body
    end
  end

  #Request for authorization
  get '/auth' do
    request_url = "#{@endpoint}/#{@auth_path}?response_type=code&client_id=#{@client_id}&redirect_uri=#{@redirect_uri}&scope=#{@granted_scopes}"
    puts request_url

    redirect request_url
  end


  get '/implicit' do
    request_url = "#{@endpoint}/#{@auth_path}?response_type=token&client_id=#{@client_id}&redirect_uri=#{@redirect_implict}&scope=#{@granted_scopes}"
    puts request_url

    redirect request_url
  end

  run!
end
