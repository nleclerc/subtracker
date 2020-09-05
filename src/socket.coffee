
Socket = require 'socket.io'

_ = require 'lodash'

log = require('log4js').getLogger('socket')
debug = require('debug')('subtracker:socket')

module.exports = (server,db,channelName)->

	io = Socket server,
		pingTimeout: 5000
		pingInterval: 3000

	log.info 'Socket initialized.'

	io.on 'connection', (socket)->
		debug 'Client connected:',socket.id

		registerService = (name,generator)->
			socket.on name, (args...)->
				callback = -> # noop

				if _.isFunction _.last(args)
					callback = _.last(args)
					args.pop()

				try
					result = await generator(args...)
					callback null,result
				catch err
					callback err

		registerService 'refresh', (refDate,callback)->
			debug 'Refreshing since:',refDate
			result = await db.listSubs channelName,refDate
			# debug 'Found rows:',result
			result

		socket.emit 'channel',channelName

	result =
		notifyNewSub: (subdata)->
			io.sockets.emit 'newsub',subdata
