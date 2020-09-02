sqlite3 = require('sqlite3').verbose()

log = require('log4js').getLogger('db')
debug = require('debug')('subtracker:db')

module.exports = (config)->

	db = new sqlite3.Database config.dbPath

	db.on 'error', (err)->
		log.error 'Database error',err

	dbAll = (sql,args...)->
		await new Promise (resolve,reject)->
			db.all sql,args..., (err,rows)->
				if err
					reject err
				else
					resolve rows

	dbRun = (sql,args...)->
		await new Promise (resolve,reject)->
			db.run sql,args..., (err)->
				if err
					reject err
				else
					resolve @

	await dbRun """
		CREATE TABLE IF NOT EXISTS `sub` (
			`id` INTEGER PRIMARY KEY AUTOINCREMENT,
			`creation_date` TEXT NOT NULL,
			`channel` TEXT NOT NULL,
			`user` TEXT NOT NULL,
			`type` TEXT NOT NULL,
			`months` INTEGER NOT NULL
		);

		CREATE INDEX IF NOT EXISTS `sub_creation_date` ON sub(`creation_date`);
	"""

	Db =
		registerSub: (data)->
			# debug 'Registering sub:',data
			await dbRun 'INSERT INTO sub (creation_date,channel,user,type,months) VALUES (?,?,?,?,?)',data.creation_date,data.channel,data.user,data.type,data.months

		cleanupSubs: (refDate)->
			await dbRun 'DELETE FROM sub WHERE creation_date < ?',refDate.toISOString()

		listSubs: (channel,refDate)->
			args = [channel]

			whereClause = ''

			if refDate?
				whereClause = 'AND creation_date > ?'
				args.push refDate

			await dbAll "SELECT * FROM sub WHERE channel=? #{whereClause} ORDER BY creation_date ASC",args...
