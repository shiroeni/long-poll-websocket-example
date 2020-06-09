# frozen_string_literal: true

require_relative 'boot'

class Handshake
  MAGIC_STRING = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11' # see rfc6455

  def initialize(client)
    puts '= Handshake from client'
    @client = client
  end

  # @return [Array<String>]
  def call
    lines.each do |line|
      if line.start_with?('Sec-WebSocket-Key')
        @key = line.split(': ').last.chomp
        break
      end
    end

    response_text.each do |line|
      client.puts line
    end
  end

  private

  attr_reader :client, :key

  # @return [Array<String>]
  def lines
    @lines ||= [].tap do |ary|
      puts 'Read lines...'
      loop do
        line = client.gets
        break if line == "\r\n"

        puts "=> #{line}"
        ary << line
      end
    end
  end

  def encoded_key
    Digest::SHA1.base64digest([key, MAGIC_STRING].join).chomp
  end

  def response_text
    puts encoded_key

    %W[
      HTTP/1.1\ 101\ Switching\ Protocols\r\n
      Upgrade:\ websocket\r\n
      Connection:\ Upgrade\r\n
      Sec-WebSocket-Accept:\ #{encoded_key}\r\n
      \r\n
    ]
  end
end

class Encoder
  def initialize(client)
    puts '= Message from client'
    @client = client
  end

  def call
    first_byte &&
      second_byte &&
      mask && payload

    unmasked_data = data.map.with_index do |byte, idx|
      byte ^ mask[i % 4]
    end.pack('C*').force_encoding('utf-8')

    puts unmasked_data
  end

  private

  attr_reader :client

  def first_byte
    byte = client.getbyte

    fin = byte & 0b10000000
    opcode = byte & 0b00001111

    opcode == 1 || !fin
  end

  def second_byte
    byte = client.getbyte

    masked = byte & 0b10000000
    payload_size = byte & 0b01111111

    puts "Payload size: #{payload}"

    !masked && payload_size < 126
  end

  def mask
    @mask ||= 4.times.map { client.getbyte }
  end

  def data
    @data ||= payload_size.times.map do
      client.getbyte
    end
  end
end

ENV['PORT'] ||= '2000'
$clients ||= []

server = TCPServer.new(ENV['PORT'])

puts "Server has started on #{ENV['PORT']}"
puts 'Waiting for a connection...'

loop do
  Thread.start(server.accept) do |client|
    puts 'New client connected!'
    $clients = $clients.push(client)

    Handshake.new(client).call

    loop do
      Encoder.new(client).call

      sleep(0.1)
    end

    client.close
    $clients = $clients - [client]
    puts 'Client closed!'
  end
end
