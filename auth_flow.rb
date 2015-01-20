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
    @endpoint =''

    @access_token_path = 'oauth/token'
    @auth_path='oauth/authorize'

    @client_id = 'my_app'
    @client_secret = 'passwd'
    @redirect_uri = 'http://localhost:4567/callback'

    #@granted_scopes=['read', 'write'].join('+')
    @granted_scopes='read'

    content_type :json
  end

  get '/callback' do
    get_token(params['code'])
  end


  def get_token(code)

    client_app_credentials = "#{@client_id}:#{@client_secret}"
    hash_credentials = Base64.encode64(client_app_credentials)
    enconde_auth = "Basic #{hash_credentials.strip}"

    conn = Faraday.new(url: @endpoint) do |c|
      c.request  :url_encoded
      c.adapter Faraday.default_adapter
    end

    res = conn.get @access_token_path do |req|
      req.params['code'] = code
      req.params['client_id'] = @client_id
      req.params['redirect_uri'] = @redirect_uri
      req.params['grant_type'] = 'authorization_code'

      req.headers['Authorization'] = enconde_auth
    end

    response = JSON.parse(res.body)

    session[:access_token] = response['access_token']
    session[:token_type] = response['token_type']
    session[:expires] = response['expires_in']
    session[:scope] = response['scope']

    res.body
  end


  get '/me' do
    conn = Faraday.new(url: "#{@endpoint}") do |c|
      c.response :json
      c.adapter Faraday.default_adapter
      c.use FaradayMiddleware::ParseJson, content_type: /\bjson$/
      c.headers = {
        'Authorization' => "OAuth #{session[:access_token]}",
        'Content-Type' => 'application/json'
      }
    end

    #TODO UPDATE
    response = conn.get do |req|
      req.url '/v2.1/me'
      req.params['fields'] = ['id', 'name', 'picture', 'education'].join(',')
    end

    response.body.to_json
  end

  #Request for authorization
  get '/auth' do
    request_url = "#{@endpoint}/#{@auth_path}?response_type=code&client_id=#{@client_id}&redirect_uri=#{@redirect_uri}&scope=#{@granted_scopes}"
    puts request_url

    redirect request_url
  end

  run!
end
