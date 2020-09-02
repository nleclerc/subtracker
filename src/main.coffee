
debug = require('debug')('subtracker:main')
config = require './config'

tmi = require 'tmi.js'
sqlite3 = require 'sqlite3'
cron = require 'node-cron'
Static = require 'node-static'
http = require 'http'
path = require 'path'

log = require('log4js').getLogger('main')
log.info 'Subtracker starting...'
debug 'Using configuration:',config

createSubData = (chan,username,type,months)->
	creation_date: new Date().toISOString()
	channel: chan.replace /^#/,''
	user: username
	type: type
	months: parseInt months,10

(->
	try
		db = await require('./db')(config)

		cron.schedule '*/10 * * * *', ->
			refDate = new Date(Date.now() - config.maxAge)
			log.debug 'Cleaning up subs older than:',refDate
			db.cleanupSubs refDate

		client = new tmi.client
			# options:
			# 	debug: true
			connection:
				reconnect: true
				secure: true
			identity:
				username: config.name
				password: config.oauthToken
			channels: [config.channel]

		await client.connect()
		# client.on 'message', (chan,tags,message,self)->
		# 	if (self) then return
		# 	console.log "[#{chan}]","#{tags['display-name']}:",message

		log.info 'Connected to:',config.channel
		log.info 'As:',config.name

		client.on 'subscription', (chan,username,methods,message,userstate)->
			try
				log.info "[#{chan}] SUB(1): #{userstate['display-name']}"#,userstate
				subData = createSubData chan,username,'sub',1
				await db.registerSub subData
				Socket.notifyNewSub subData
			catch err
				log.error 'Error handling sub:',err

		client.on 'resub', (chan,username,months,message,userstate,methods)->
			try
				log.info "[#{chan}] RESUB(#{userstate['msg-param-cumulative-months']}): #{userstate['display-name']}"#,userstate
				subData = createSubData chan,username,'resub',userstate['msg-param-cumulative-months']
				await db.registerSub subData
				Socket.notifyNewSub subData
			catch err
				log.error 'Error handling resub:',err

		fileServerPath = path.join(__dirname,'public')
		fileServer = new Static.Server fileServerPath
		debug 'Serving files from:',fileServerPath

		server = http.createServer((req,res)->
			req.addListener('end', -> fileServer.serve req,res).resume()
		)

		Socket = require('./socket')(server,db,config.channel)

		server.listen config.listenPort,config.listenAddress, (args...)->
			serverAddress = server.address()
			log.info 'Server listening on %s:%d.', serverAddress.address, serverAddress.port,
	catch error
		log.error error
		process.exit 1
)()
