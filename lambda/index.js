const AWS = require('aws-sdk');
const https = require('https');
const querystring = require('querystring');
const keepAliveAgent = new https.Agent({keepAlive: true});
const S3 = new AWS.S3({signatureVersion: 'v4',httpOptions: {agent: keepAliveAgent}});
const Sharp = require('sharp');

// import AWS from 'aws-sdk';
// import https from 'https';
// import querystring from 'querystring';
// import Sharp from 'sharp';

exports.handler = (event, context, callback) => {

  const request = event.Records[0].cf.request;
  const params = querystring.parse(request.querystring);

  let s3DomainName = request.origin.s3.domainName;

  //remove the s3.amazonaws.com
  let BUCKET = s3DomainName.substring(0,s3DomainName.lastIndexOf(".s3"));

  console.log("Bucket:%s", BUCKET);
  console.log("Image:%s", request.uri);
  console.log(request);

  console.log(JSON.stringify(params));
  var resizingOptions = {};

  if (params.width) resizingOptions.width = parseInt(params.width);

  // get the source image file
  S3.getObject({ Bucket: BUCKET, Key: request.uri.substring(1) }).promise()
    // perform the resize operation
    .then(data => Sharp(data.Body)
      .resize(resizingOptions)
      .toFormat(params.format)
      .toBuffer()
    )
    .then(buffer => {
      let base64String = buffer.toString('base64');
      if(base64String.length > 1048576){
        throw 'Resized filesize payload is greater than 1 MB.Returning original image'
      }
      console.log("Length of response :%s",base64String.length);
      // generate a binary response with resized image
      let response = {
           status: '200',
           statusDescription: 'OK',
           headers: {
               'cache-control': [{
                   key: 'Cache-Control',
                   value: 'max-age=84600,stale-while-revalidate=300,stale-if-error=3600'
                }],
               'content-type': [{
                   key: 'Content-Type',
                   value: 'image/'+ params.format
               }]
           },
           bodyEncoding: 'base64',
           body: base64String
       };

      callback(null,response);
    })
  .catch( err => {
    console.log("Exception while reading source image :%j",err);
    callback(null,request);
  });
};
