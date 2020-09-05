
debug = require('debug')('subtracker:main')
config = require './config'

tmi = require 'tmi.js'
sqlite3 = require 'sqlite3'
cron = require 'node-cron'
Express = require 'express'
http = require 'http'
path = require 'path'
CsvStringify = require 'csv-stringify'
Moment = require 'moment'

log = require('log4js').getLogger('main')
log.info 'Subtracker starting...'
debug 'Using configuration:',config

CSV_HEADERS = [
	'date'
	'channel'
	'username'
	'type'
	'months'
]

CSV_OPTIONS =
	delimiter: ';'

CSV_DATE_FORMAT = 'YYYY-MM-DD HH:mm:ss'

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
				debug "[#{chan}] SUB(1): #{userstate['display-name']}"#,userstate
				subData = createSubData chan,username,'sub',1
				await db.registerSub subData
				Socket.notifyNewSub subData
			catch err
				log.error 'Error handling sub:',err

		client.on 'resub', (chan,username,months,message,userstate,methods)->
			try
				debug "[#{chan}] RESUB(#{userstate['msg-param-cumulative-months']}): #{userstate['display-name']}"#,userstate
				subData = createSubData chan,username,'resub',userstate['msg-param-cumulative-months']
				await db.registerSub subData
				Socket.notifyNewSub subData
			catch err
				log.error 'Error handling resub:',err

		app = Express()
		app.set 'trust proxy',true # allows proper access to client visible host including wether connection was secured with ssl.

		publicFolderPath = path.join(__dirname,'public')
		app.set 'public',publicFolderPath
		app.use Express.static(publicFolderPath)
		debug 'Serving files from:',publicFolderPath

		app.get '/downloadcsv', (req,res)->
			debug 'Processing CSV request.'
			subs = await db.listSubs(config.channel)
			debug 'Subs found:',subs.length

			csvData = [CSV_HEADERS]

			for sub in subs ? []
				csvData.push [
					Moment(sub.creation_date).format CSV_DATE_FORMAT
					sub.channel
					sub.user
					sub.type
					sub.months
				]

			stringifier = CsvStringify csvData,CSV_OPTIONS, (err,output)->
				if err
					log.error 'Error generating CSV:',err
					res.status(500).end()
				else
					res.attachment("#{Moment().format('YYYY-MM-DD_HH-mm-ss')}-subs_#{config.channel}.csv").send(output).end()

		server = http.createServer(app)

		Socket = require('./socket')(server,db,config.channel)

		server.listen config.listenPort,config.listenAddress, (args...)->
			serverAddress = server.address()
			log.info 'Server listening on %s:%d.', serverAddress.address, serverAddress.port,
	catch error
		log.error error
		process.exit 1
)()
