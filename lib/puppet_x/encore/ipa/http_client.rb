require 'net/https'
require 'ipaddr'
require 'json'
require 'puppet_x/encore/ipa'
require 'puppet'

module PuppetX::Encore::Ipa
  # Client class for HTTP calls
  class HTTPClient
    attr_accessor :headers

    def initialize(base_url: nil,
                   username: nil,
                   password: nil,
                   ssl_verify: OpenSSL::SSL::VERIFY_NONE,
                   redirect_limit: 10,
                   headers: {})
      @base_url = base_url
      @username = username
      @password = password
      @ssl_verify = ssl_verify
      @redirect_limit = redirect_limit
      @headers = headers
    end

    def update_headers(hdrs)
      @headers.update(hdrs)
    end

    def execute(method, url, body: nil, headers: {}, redirect_limit: @redirect_limit, form: nil, params: nil)
      raise ArgumentError, 'HTTP redirect too deep' if redirect_limit.zero?

      Puppet.debug("http_client - execute - method = #{method}")
      Puppet.debug("http_client - execute - url = #{url}")

      # setup our HTTP class
      uri = URI.parse(url)
      uri.query = URI.encode_www_form(params) unless params.nil?
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = @ssl_verify

      # create our request
      req = net_http_request_class(method).new(uri)
      req.basic_auth(@username, @password) if @username && @password

      # copy headers into the request
      headers.each { |k, v| req[k] = v }

      # set the body in the request
      if body
        case body
        when Array, Hash then
          req.content_type = 'application/json'
          req.body = body.to_json
        else
          req.body = body
        end
        Puppet.debug("http_client - execute - body = #{req.body}")
      elsif form
        enctype = headers['Content-Type'] || headers['content-type'] || 'application/x-www-form-urlencoded'
        req.set_form(form, enctype)
        Puppet.debug("http_client - execute - setting form data - body = #{req.body}")
      end

      # execute
      Puppet.debug("http_client - execute - executing request=#{req}\n  body=#{req.body}")
      resp = http.request(req)
      Puppet.debug("http_client - execute - received response=#{resp}\n  body=#{resp.body}")

      # check response for success, redirect or error
      case resp
      when Net::HTTPSuccess then
        resp
      when Net::HTTPRedirection then
        execute(method,
                resp['location'],
                body: body,
                headers: headers,
                redirect_limit: redirect_limit - 1,
                form: form,
                params: params)
      else
        Puppet.debug("throwing HTTP error: request_method=#{method} request_url=#{url} request_body=#{body} response_http_code=#{resp.code} resp_message=#{resp.message} resp_body=#{resp.body}")
        stack_trace = caller.join("\n")
        Puppet.debug("Raising exception: #{resp.error_type.name}")
        Puppet.debug("stack trace: #{stack_trace}")
        message = 'code=' + resp.code
        message += ' message=' + resp.message
        message += ' body=' + resp.body
        raise resp.error_type.new(message, resp)
      end
    end

    def net_http_request_class(method)
      Net::HTTP.const_get(method.capitalize, false)
    end

    def ip?(str)
      IPAddr.new(str)
      true
    rescue
      false
    end

    def get(url, body: nil, headers: @headers, form: nil, params: nil)
      execute('get', url, body: body, headers: headers, redirect_limit: @redirect_limit, form: form, params: params)
    end

    def post(url, body: nil, headers: @headers, form: nil, params: nil)
      execute('post', url, body: body, headers: headers, redirect_limit: @redirect_limit, form: form, params: params)
    end

    def put(url, body: nil, headers: @headers, form: nil, params: nil)
      execute('put', url, body: body, headers: headers, redirect_limit: @redirect_limit, form: form, params: params)
    end

    def delete(url, body: nil, headers: @headers, form: nil, params: nil)
      execute('delete', url, body: body, headers: headers, redirect_limit: @redirect_limit, form: form, params: params)
    end

    def make_url(endpoint)
      "#{base_url}#{endpoint}"
    end
  end
end
