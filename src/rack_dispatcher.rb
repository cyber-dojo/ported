require_relative 'client_error'
require_relative 'well_formed_args'
require 'json'

class RackDispatcher

  def initialize(externals, request_class)
    @externals = externals
    @request_class = request_class
  end

  def call(env)
    request = @request_class.new(env)
    path = request.path_info[1..-1]
    body = request.body.read
    target, name, args = validated_name_args(path, body)
    result = target.public_send(name, *args)
    json_response(200, plain({ name => result }))
  rescue Exception => error
    diagnostic = pretty({
      'exception' => {
        'path' => path,
        'body' => body,
        'class' => 'MapperService',
        'message' => error.message,
        'backtrace' => error.backtrace
      }
    })
    $stderr.puts(diagnostic)
    $stderr.flush
    json_response(code(error), diagnostic)
  end

  private # = = = = = = = = = = = = = = = = = = =

  def validated_name_args(name, body)
    env = @externals.env
    mapper = @externals.mapper
    wfa = WellFormedArgs.new(body)
    args = case name
      when /^ready$/     then [mapper]
      when /^sha$/       then [env]
      when /^mapped$/    then [mapper, wfa.id6]
      when /^mapped_id$/ then [mapper, wfa.partial_id]
      else
        raise ClientError, "#{name}:unknown:"
    end
    name += '?' if query?(name)
    target = args.shift
    [target, name, args]
  end

  # - - - - - - - - - - - - - - - -

  def json_response(status, body)
    [ status,
      { 'Content-Type' => 'application/json' },
      [ body ]
    ]
  end

  def code(error)
    if error.is_a?(ClientError)
      400
    else
      500
    end
  end

  def plain(body)
    JSON.generate(body)
  end

  def pretty(body)
    JSON.pretty_generate(body)
  end

  def query?(name)
    ['ready','mapped'].include?(name)
  end

end
