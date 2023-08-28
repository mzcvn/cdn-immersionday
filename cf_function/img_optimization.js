function handler(event) {
    var request = event.request;
    if ((request.querystring.format) && (request.querystring.format.value === "auto")) {
        console.log('auto format detected');
        if ((request.headers['accept']) && (request.headers['accept'].value.includes("webp"))) {
            request.querystring.format.value = "webp";
        } else {
            request.querystring.format.value = "png";
        }

    }
    return request;
}
