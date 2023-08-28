exports.handler = async (event) => {
  const response = {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "max-age=5,stale-while-revalidate=300,stale-if-error=100"
      },
    "isBase64Encoded": false,
    "multiValueHeaders": { 
      "X-Custom-Header": ["My value", "My other value"],
    },
    statusCode: process.env.StatusCode,
    body: process.env.StatusCode == 200 ? JSON.stringify('Hello Lambda!') : {"error": "Internal server error"}
  };
  return response;
};
