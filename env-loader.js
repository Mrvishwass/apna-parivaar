(function(){
  async function loadEnv(){
    try {
      const res = await fetch('./env.local', { cache: 'no-store' });
      if (!res.ok) return;
      const text = await res.text();
      const env = {};
      text.split(/\r?\n/).forEach(line => {
        const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
        if (!m) return;
        const key = m[1];
        let val = m[2];
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
          val = val.slice(1, -1);
        }
        env[key] = val;
      });
      window.ENV = {
        SUPABASE_URL: env.SUPABASE_URL,
        SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
        EDGE_URL: env.EDGE_URL,
        UPI_QR_URL: env.UPI_QR_URL,
      };
    } catch (e) {
      console.warn('ENV loader failed', e);
    }
  }
  loadEnv();
})();


