# /*
#  * mqtt-rpc
#  * https://github.com/wolfeidau/mqtt-rpc
#  *
#  * Copyright (c) 2013 Mark Wolfe
#  * Licensed under the MIT license.
#  */
import mqtt from 'mqtt'
import mqttrouter from 'mqtt-router'
import codecs from './codecs.js'
import Debug from 'debug'

debug = Debug('mqtt-rpc:server')

export default class Server
  constructor(mqttclient) ->
    # default to JSON codec
    @codec = codecs.byName('json')

    @mqttclient = mqttclient || mqtt.createClient()

    @router = mqttrouter.wrap(mqttclient)

  _handleReq: (correlationId, prefix, name, err, data) =>
    replyTopic = prefix + '/' + name + '/reply'

    msg = {err: err, data: data, _correlationId: correlationId}

    debug('publish', replyTopic, msg)

    @mqttclient.publish(replyTopic, @codec.encode(msg))

  _buildRequestHandler = (prefix, name, cb) =>
    debug('buildRequestHandler', prefix, name)

    (topic, message) =>
      debug('handleMsg', topic, message);

      msg = @codec.decode(message)
      id = msg._correlationId

      cb.call(null, msg, @_handleReq.bind(null, id, prefix, name))

  provide: (prefix, name, cb) ->
    debug('provide', prefix, name)

    requestTopic = prefix + '/' + name + '/request'

    debug('requestTopic', requestTopic);

    @router.subscribe(requestTopic, @_buildRequestHandler(prefix, name, cb))

    debug('subscribe', requestTopic)

  @format = (format) ->
    this.codec = codecs.byName(format)
