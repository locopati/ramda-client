require 'net/http'
require 'json'

# simple client for making GraphQL requests to Github
class GithubGqlClient

  ENDPOINT = 'https://api.github.com/graphql'.freeze

  def initialize(token, debug = false)
    @token = token
    @debug = debug
  end

  def request(query, variables = nil)
    uri = URI(ENDPOINT)
    req = Net::HTTP::Post.new(uri)
    body = {query: query.gsub('\n','')}
    body.merge!({variables: variables}) if variables
    req.body = body.to_json
    req['Authorization'] = "bearer #{@token}"

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.set_debug_output $stdout if @debug
    res = http.start do |h|
      h.request(req)
    end

    begin
      json = JSON.parse res.body
      raise StandardError, json['errors'] if json['errors']
      json['data']
    rescue => e
      puts e
    end
  end
end