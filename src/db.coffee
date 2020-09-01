sqlite3 = require('sqlite3').verbose()

log = require('log4js').getLogger('db')

module.exports = (config)->

	db = new sqlite3.Database config.dbPath

	db.on 'error', (err)->
		log.error 'Database error',err

	dbExec = (sql,args...)->
		await new Promise (resolve,reject)->
			db.exec sql,args..., (err)->
				if err
					reject err
				else
					resolve()

	dbRun = (sql,args...)->
		await new Promise (resolve,reject)->
			db.run sql,args..., (err)->
				if err
					reject err
				else
					resolve @

	await dbExec """
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
		registerSub: (channel,user,type,months)->
			await dbRun 'INSERT INTO sub (creation_date,channel,user,type,months) VALUES (?,?,?,?,?)',new Date().toISOString(),channel,user,type,months

		cleanupSubs: (refDate)->
			await dbRun 'DELETE FROM sub WHERE creation_date < ?',refDate.toISOString()
