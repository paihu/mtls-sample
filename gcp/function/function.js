const functions = require('@google-cloud/functions-framework');

functions.http('mtls-test',(req,res)=>{
	res.send(JSON.stringify(req.rawHeaders));
})
