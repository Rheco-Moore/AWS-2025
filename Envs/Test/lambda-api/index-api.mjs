index-api.mjs
export const handler = async (event) => {
  return {
    statusCode: 200,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: "Hello from JSON API Lambda!",
      path: event.rawPath,
      method: event.requestContext?.http?.method,
    }),
  };
};
