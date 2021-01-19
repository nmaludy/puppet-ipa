require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                   'puppet_x', 'encore', 'ipa', 'http_client'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..',
                                   'puppet_x', 'encore', 'ipa', 'cache'))
require 'cgi'

# This class is a "base" provider to use to implement your own custom providers here
# at Encore.
class Puppet::Provider::Ipa < Puppet::Provider
  ##########################
  # public methods inherited from Puppet::Provider

  # defines our getter & setter methods that assign stuff to @property_hash
  # this creates a bunch of methods like:
  #   def full_name
  #     @property_hash[:full_name]
  #   end
  #
  #   def full_name=(value)
  #     @property_hash[:full_name] = value
  #   end
  #
  # This allows us to capture the properties that are changed inside of @property_hash
  # and write all of the changes at one time.
  # If we did not use this, we would have to implement the above getter and setter
  # methods and in each setter write the changed property to the API (not very efficient)
  #
  # @note: sub-classes MUST to call this in their own class, otherwise if we define it here
  # we get an error:
  #  Error: Could not autoload puppet/provider/encore_elasticsearch_user/api: undefined method `validproperties' for nil:NilClass
  #
  # mk_resource_methods

  # the exists method should return true if the current named resource exists or not
  # in this method we also get the instance of this resource from the API and save
  # it to our @property_hash, this initializes @property_hash and allows it to be
  # used by the mk_resource_methods getter and setters above.
  def exists?
    # use cloned cached_instance here so we can compare before/after in flush() if needed
    @property_hash = cached_instance.clone
    @property_hash[:ensure] == :present
  end

  # this method is called if exists? returns false and :ensure == :present,
  #   so that the resource is created
  # you have two options:
  # 1) implement your "creation" API call here
  # 2) defer the creation to the "flush" method so that "create" and "update" can be
  #    handled in the exact same way
  def create
    @property_hash[:ensure] = :present
  end

  # this method is called if exists? returns false and :ensure == :absent,
  #   so that the resource is deleted
  # 1) implement your "deletion" API call here
  # 2) defer the deletion to the "flush" method so we are consistent with what
  #    we're doing above
  def destroy
    @property_hash[:ensure] = :absent
  end

  # the flush method is called at the end of the "transaction" once all setter methods
  # above have been called along with exists? and potentially create or delete.
  # this method should take all changes that need to happen to this resource and
  # make the necessary API calls to make them happen.
  # In our case we're going to do one "bulk" API call for all of our properties
  # to either create or update the user.
  # If the resource was requested to be destroyed we will delete the resource
  # using the API.
  #
  # This allows us to be super efficiently and basically make one "write" call
  # for each resource instance.
  def flush
    flush_instance

    # Collect the resources again once they've been changed (that way `puppet
    # resource` will show the correct values after changes have been made).
    @property_hash = read_instance
  end

  ##########################
  # private methods
  #
  # You as an implementer need to define 3x methods below
  # - cached_instance : This is just a cache of read_instance, we've provided a default
  #                     implementation so implementers of sub-classes don't have to worry
  # - read_instance : this should return a hash that has the same properties (as symbols)
  #                   and values of what the resource currently looks like
  # - flush_instance : this should read from resource[:xxx] and either create/update or
  #                    delete the instance based on the value of @property_hash[:ensure]
  def cached_instance
    @cached_instance ||= read_instance
  end

  # this method should retrieve an instance and return it as a hash
  # note: we explicitly do NOT cache within this method because we want to be
  #       able to call it both in initialize() and in flush() and return the current
  #       state of the resource from the API each time
  def read_instance
    raise NotImplementedError, 'read_instance needs to be implemented by child providers'
  end

  # this method should check resource[:ensure]
  #  if it is :present this method should create/update the instance using the values
  #  in resource[:xxx] (these are the desired state values)
  #  else if it is :absent this method should delete the instance
  #
  #  if you want to have access to the values before they were changed you can use
  #  cached_instance[:xxx] to compare against (that's why it exists)
  def flush_instance
    raise NotImplementedError, 'flush_instance needs to be implemented by child providers'
  end

  def api_client
    # create an HTTP client with this username/password and cache it
    # be sure to use resource[:xxx] here so that we can use the parameters
    # set by the user in the DSL declaration of this resource
    client_id = resource[:api_url] + resource[:api_username]
    client = PuppetX::Encore::Ipa::Cache.instance.cached_clients[client_id]
    if client.nil?
      client = PuppetX::Encore::Ipa::HTTPClient.new(headers: { 'Referer' => api_make_url('') })
      api_login(client: client)
      # only save client to cache upon successful login
      PuppetX::Encore::Ipa::Cache.instance.cached_clients[client_id] = client
    end
    client
  end

  def api_make_url(endpoint)
    "#{resource[:api_url]}#{endpoint}"
  end

  def api_login(username: resource[:api_username],
                password: resource[:api_password],
                persist_auth: true,
                client: api_client)
    # https://access.redhat.com/articles/2728021#end-point-pwd
    headers = {
      'Content-Type' => 'application/x-www-form-urlencoded',
      'Accept' => 'text/plain',
    }
    form = {
      'user' => username,
      'password' => password,
    }
    response = client.post(api_make_url('/session/login_password'),
                           form: form,
                           headers: headers)
    # note: don't check for API response 'error' key here because the response
    # is plain text and not JSON
    if persist_auth
      cookies = response.get_fields('Set-Cookie')
      client.update_headers('Cookie' => cookies.join('; '))
    end
    response
  end

  def api_response_raise_if_error(response)
    body = JSON.parse(response.body)
    error = body['error']
    return response unless error

    raise Puppet::Error, "Received API error from IPA: #{error}"
  end

  def api_post(endpoint, body: nil, json_parse: true)
    response = api_client.post(api_make_url(endpoint), body: body)
    api_response_raise_if_error(response)
    if json_parse
      JSON.parse(response.body)
    else
      response
    end
  end
end
