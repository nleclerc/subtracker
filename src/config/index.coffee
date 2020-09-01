
require './log4js'

try
	conf = require '../../etc/config.json'
	module.exports = conf
catch err
	if err.code is 'MODULE_NOT_FOUND'
		console.error 'Configuration file not found. Did you copy config.json.dist to config.json in etc folder?'
		process.exit 1

	throw err
