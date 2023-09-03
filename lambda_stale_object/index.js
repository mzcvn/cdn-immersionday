exports.handler = async (event) => {
  const response = {
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "max-age=86400,stale-while-revalidate=300,stale-if-error=100"
      },
    "isBase64Encoded": false,
    "multiValueHeaders": { 
      "X-Custom-Header": ["My value", "My other value"],
    },
    statusCode: process.env.StatusCode,
    body: process.env.StatusCode == 200 ? JSON.stringify('Welcome to the event - Leveraging the Power of CloudFront and Edge Computing') : {"error": "Internal server error"}
  };
  return response;
};
