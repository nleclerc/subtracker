
Socket = require 'socket.io'

_ = require 'lodash'

log = require('log4js').getLogger('socket')
debug = require('debug')('subtracker:socket')

filterChannelNames = (list)->
	for chan in list
		chan.replace /^#/,''

module.exports = (server,db,channelList)->
	channelList = filterChannelNames channelList
	debug 'Using channel list:',channelList

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
					debug 'Service error:',name,err
					callback err

		registerService 'channel:track', (name)->
			unless channelList.includes name
				throw new Error 'INVALID_CHANNEL'

			for chan in channelList
				socket.leave chan

			socket.join name
			null

		registerService 'refresh', (channel,refDate)->
			debug 'Refreshing:',channel,refDate
			result = await db.listSubs channel,refDate
			# debug 'Found rows:',result
			result

		socket.emit 'channels',channelList

	result =
		notifyNewSub: (subdata)->
			debug 'Notifying sub:',subdata
			io.sockets.to(subdata.channel).emit 'newsub',subdata
