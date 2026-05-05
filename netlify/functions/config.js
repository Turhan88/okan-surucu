/**
 * Serves Supabase public config to the frontend.
 * Anon key is safe to expose; service_role key NEVER leaves this function.
 */
exports.handler = async () => {
  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/javascript',
      'Cache-Control': 'public, max-age=3600'
    },
    body: `window.APP_CONFIG = ${JSON.stringify({
      SUPABASE_URL:      process.env.SUPABASE_URL      || '',
      SUPABASE_ANON_KEY: process.env.SUPABASE_ANON_KEY || ''
    })};`
  };
};
