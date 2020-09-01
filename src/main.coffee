
debug = require('debug')('subtracker:main')
config = require './config'

tmi = require 'tmi.js'
sqlite3 = require 'sqlite3'
cron = require 'node-cron'

log = require('log4js').getLogger('main')
log.info 'Subtracker starting...'
debug 'Using configuration:',config

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
				username: 'subtracker'
				password: config.oauthToken
			channels: [config.channel]

		await client.connect()
		# client.on 'message', (chan,tags,message,self)->
		# 	if (self) then return
		# 	console.log "[#{chan}]","#{tags['display-name']}:",message

		log.info 'Connected to:',config.channel

		client.on 'subscription', (chan,username,methods,message,userstate)->
			log.info "[#{chan}] SUB(1): #{userstate['display-name']}"#,userstate
			db.registerSub chan,username,'sub',1

		client.on 'resub', (chan,username,months,message,userstate,methods)->
			log.info "[#{chan}] RESUB(#{userstate['msg-param-cumulative-months']}): #{userstate['display-name']}"#,userstate
			db.registerSub chan,username,'resub',userstate['msg-param-cumulative-months']
	catch error
		log.error error
		process.exit 1
)()
