const yargs 	= require('yargs');
const ewelink 	= require('ewelink-api');
const fs 		= require('fs');

var express 	= require('express')
var app 		= express()

const options = {
  key: fs.readFileSync('key.pem'),
  cert: fs.readFileSync('cert.pem')
};
const https 	= require('https').createServer(options, app);  //const http = require('http').createServer(app);

//-------------------------------------------------------------------------------------------------------------------------//
let xmsServerCredentials = JSON.parse(fs.readFileSync('credentials.xmsGateway.json'));
let eWeLinkCredentials = JSON.parse(fs.readFileSync('credentials.eWeLink.json'));

//-------------------------------------------------------------------------------------------------------------------------//
const argv = yargs
    .option('severity', {
        alias: 's',
        description: 'log level',
        type: 'number',
    })
    .help()
    .alias('help', 'h')
    .argv;

//-------------------------------------------------------------------------------------------------------------------------//
const connection = new ewelink({
  email: eWeLinkCredentials.login,
  password: eWeLinkCredentials.password,
  region: 'eu'
});

//-------------------------------------------------------------------------------------------------------------------------//
function checkAuthorization(req) {
	
	var aut = req.headers['autorization'];
	var autOk = true;
	
	if (aut == undefined) {
		autOk = false;
	} else {
		aut = aut.replace("Basic ","");
		let buff = new Buffer(aut, 'base64');
		try {
			let loginPassword = buff.toString('ascii');
			const loginPasswordArray = loginPassword.split(':');
			if (loginPasswordArray.length != 2) {
				console.debug('loginPassword is incorrect : ', loginPassword);
				autOk = false;
			} else {
				let login = loginPasswordArray[0];
				let passwd = loginPasswordArray[1];
				if (login != xmsServerCredentials.login || passwd != xmsServerCredentials.password) {
					console.debug('incorrect credentials !!');
					autOk = false;
				}
			}
		} catch(error) {
			console.debug('could not decode base64 aut : ', aut);
			autOk = false;
		}
	}
	
	return autOk;
}

//-------------------------------------------------------------------------------------------------------------------------//
app.get('/', function (req, res) {	
	res.set('Content-Type', 'application/json')
	result = { "status" : "ko", "cause" : "this path is not supported ; you can got to /help to get usage" };
	res.status(412).send(result);		
});

//-------------------------------------------------------------------------------------------------------------------------//
app.get('/help', function (req, res) {	
	res.set('Content-Type', 'application/json')
	result = { "server info": "custom diy homemade ewelink gateway to control my devices", "available-commands" : ['detail-device', 'control-device', 'all-devices'] };
	res.send(result);		
});

//-------------------------------------------------------------------------------------------------------------------------//
app.get('/all-devices', async function (req, res) {
	
	let autOk = checkAuthorization(req);	
	
	res.set('Content-Type', 'application/json')
	if (!autOk) {
		result = { "status" : "ko", "cause" : "missing or invalid authorization header; need a basic authorization header"};
		res.status(401).send(result);
		return;
	}
	
	const infoDevices = await connection.getDevices();	
	res.send(infoDevices);				
});

//-------------------------------------------------------------------------------------------------------------------------//
app.get('/detail-device', async function (req, res) {
	
	let autOk = checkAuthorization(req);	
	
	res.set('Content-Type', 'application/json')
	if (!autOk) {
		result = { "status" : "ko", "cause" : "missing or invalid authorization header; need a basic authorization header"};
		res.status(401).send(result);
		return;
	}

	let devid = req.query.deviceid;
	if (devid == undefined) {
		res.status(412).send('missing parameters');		
		return;
	}	
	
	const infoDevice = await connection.getDevice(devid);	
	res.send(infoDevice);			
});

//-------------------------------------------------------------------------------------------------------------------------//
app.get('/control-device', async function (req, res) {
	
	let autOk = checkAuthorization(req);	
	
	res.set('Content-Type', 'application/json')
	if (!autOk) {
		result = { "status" : "ko", "cause" : "missing or invalid authorization header; need a basic authorization header"};
		res.status(401).send(result);
		return;
	}

	let devid = req.query.deviceid;
	let state = req.query.state;
	
	if (devid == undefined || state == undefined) {
		res.status(412).send('missing parameters');		
		return;
	}	
	
	const status = await connection.setDevicePowerState(devid, state);	
	res.send(status);		
});

//-------------------------------------------------------------------------------------------------------------------------//
https.listen(3000, function() {
  var host = https.address().address
  var port = https.address().port
  console.log('App listening at https://%s:%s', host, port)
});


/*
async function Main() {	
	console.log(process.argv);	
	const devices = await connection.getDevices(); console.log(devices);		
	const device = await connection.getDevice('1000910231'); console.log(device);	
	const status = await connection.setDevicePowerState('1000910231', 'off'); console.log(status);	
}
Main();

//connection.getDevices()
//.then(function(data) { console.log(data); });
*/


// curl -k  "https://192.168.1.253:3000/control-device?deviceid=111&state=on" -H "Autorization: Basic base64EncodedUser2PointPassword"
// curl -k  "https://localhost:3000/control-device?deviceid=1000910231&state=on" -H "Autorization: Basic eGF2aWVyLm1hcnF1aXNAZ21haWwuY29tOmZyZWUxOTc5"