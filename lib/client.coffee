# /*
#  * mqtt-methods
#  * https://github.com/boomfly/mqtt-methods
#  * https://github.com/wolfeidau/mqtt-rpc
#  *
#  * Copyright (c) 2013 Mark Wolfe
#  * Licensed under the MIT license.
#  */
import crypto from 'crypto'
import mqtt from 'mqtt'
import mqttrouter from 'mqtt-router'
import codecs from './codecs.js'
import Debug from 'debug'

debug = Debug('mqtt-methods:client')

export default class Client
  constructor: (mqttclient) ->
    # default to JSON codec
    @codec = codecs.byName('json')

    @mqttclient = mqttclient or mqtt.createClient()

    @router = mqttrouter.wrap(mqttclient)

    @inFlight = {}

  _generator: () -> crypto.randomBytes(5).readUInt32BE(0).toString(16)

  _handleResponse: (topic, message) =>
    msg = @codec.decode(message)
    id = msg._correlationId

    debug('handleResponse', topic, id, 'message', message)
    debug('inflight', @inFlight[id])

    if id and @inFlight[id]
      @inFlight[id].cb(msg.err, msg.data)
      delete @inFlight[id]

  _sendMessage: (topic, message, cb) ->
    id = @_generator()

    debug('sendMessage', topic, id, message)

    @inFlight[id] = {cb: cb}

    message._correlationId = id

    @mqttclient.publish(topic, @codec.encode(message))

  callRemote: (prefix, name, args, cb) ->
    replyTopic = prefix + '/' + name + '/reply'
    requestTopic = prefix + '/' + name + '/request'

    @router.subscribe(replyTopic, @_handleResponse)

    debug('callRemote', 'subscribe', replyTopic)

    @_sendMessage(requestTopic, args, cb)

  format: (format) ->
    @codec = codecs.byName(format)
